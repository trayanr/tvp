"""Collect explicitly bound local receipts; never execute or admit a workload."""

import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile

from verifier import atomic_report, require, store_path, unique_object

KINDS = ('focused', 'review', 'resolution', 'qualification', 'latest', 'lineage', 'protection')
REQUIRED = ('focused', 'review', 'qualification', 'latest')
STATUSES = ('PASS', 'FAIL', 'XPASS', 'SKIP', 'ABSENT', 'QUALIFIED_NONPASS', 'ACTIVE', 'PARTIAL')
LIMITS = [
    'Hashes verify supplied bytes and bindings, not truth or fresh execution of evidence claims.',
    'No builds, store queries, services, network, publication, or latest verification were invoked.',
    'Selected receipt scope only; no full conformance, security parity, or admission certification.',
    'HARDENING-GATE-1 remains open and unwaived; coverage claims cannot close it.',
]


def fields(value, expected, label):
    require(isinstance(value, dict) and set(value) == set(expected.split()), 'Invalid ' + label + ' fields')


def text(value):
    require(isinstance(value, str) and value.strip(), 'Nonempty string required')


def strings(value, empty=True):
    require(isinstance(value, list), 'String list required')
    for item in value:
        text(item)
    require(len(set(value)) == len(value) and (empty or value), 'Duplicate or empty string list')


def subject(value):
    fields(value, 'path revision tree narHash', 'source identity')
    store_path(value['path'])
    for key in ('revision', 'tree'):
        require(isinstance(value[key], str) and re.fullmatch('[0-9a-f]{40}', value[key]), 'Invalid ' + key)
    require(isinstance(value['narHash'], str) and re.fullmatch(r'sha256-[A-Za-z0-9+/]{43}=', value['narHash']),
            'Invalid source NAR hash')


def scope(value):
    fields(value, 'families description', 'scope')
    strings(value['families'], empty=False)
    text(value['description'])


def covers(outer, inner):
    return set(inner['families']) <= set(outer['families'])


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n').encode()


class Inputs:
    def __init__(self):
        self.hashes = {}

    def read(self, path, expected=None, parse=True):
        path = Path(path).resolve(strict=True)
        data = path.read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        if expected is not None:
            require(isinstance(expected, str) and re.fullmatch('[0-9a-f]{64}', expected), 'Invalid SHA256')
            require(sha == expected, 'Input hash mismatch: ' + str(path))
        require(str(path) not in self.hashes or self.hashes[str(path)] == sha, 'Input changed while collecting')
        self.hashes[str(path)] = sha
        if not parse:
            return None
        def invalid_constant(value):
            raise ValueError('Nonfinite JSON number: ' + value)
        def finite_float(value):
            number = float(value)
            require(math.isfinite(number), 'Nonfinite JSON number: ' + value)
            return number
        return json.loads(data, object_pairs_hook=unique_object, parse_constant=invalid_constant,
                          parse_float=finite_float)

    def artifact(self, row, base):
        fields(row, 'path sha256 format', 'artifact')
        text(row['path'])
        require(row['format'] in ('json', 'bytes'), 'Invalid artifact format')
        return self.read(base / row['path'], row['sha256'], row['format'] == 'json')


def records(value):
    require(isinstance(value, list), 'Records must be a list')
    ids = set()
    for row in value:
        fields(row, 'id status detail', 'record')
        text(row['id']); text(row['detail'])
        require(row['id'] not in ids and row['status'] in STATUSES, 'Invalid/duplicate record')
        ids.add(row['id'])


def collect(manifest_path):
    inputs = Inputs()
    manifest_path = Path(manifest_path).resolve(strict=True)
    m = inputs.read(manifest_path)
    fields(m, 'schema subject scope references', 'manifest')
    require(m['schema'] == 'tvp.batch-manifest/v1', 'Unsupported manifest schema')
    subject(m['subject']); scope(m['scope'])
    require(isinstance(m['references'], list), 'References must be a list')
    refs, docs = {}, {}
    for ref in m['references']:
        fields(ref, 'id kind path sha256 subject scope lineage', 'reference')
        text(ref['id']); text(ref['path'])
        require(ref['id'] not in refs and ref['kind'] in KINDS, 'Invalid/duplicate reference')
        subject(ref['subject']); scope(ref['scope']); strings(ref['lineage'])
        require(covers(m['scope'], ref['scope']), 'Reference exceeds selected families')
        path = (manifest_path.parent / ref['path']).resolve(strict=True)
        doc = inputs.read(path, ref['sha256'])
        fields(doc, 'schema kind subject scope claims artifacts', 'envelope')
        require(doc['schema'] == 'tvp.batch-evidence/v1', 'Unsupported evidence schema')
        require(all(doc[k] == ref[k] for k in ('kind', 'subject', 'scope')), 'Reference/envelope binding mismatch')
        require(isinstance(doc['artifacts'], list), 'Artifacts must be a list')
        for artifact in doc['artifacts']:
            inputs.artifact(artifact, path.parent)
        refs[ref['id']], docs[ref['id']] = ref, doc

    # Validate envelope shapes before following forward references.
    shapes = {
        'focused': 'status records limitations', 'review': 'status findings limitations',
        'resolution': 'review finding status detail proofs',
        'qualification': 'records openGates limitations',
        'latest': 'status terminal workerActive observation limitations',
        'lineage': 'from to mode proofs resolutions reason', 'protection': 'domain files',
    }
    for doc in docs.values():
        fields(doc['claims'], shapes[doc['kind']], doc['kind'])
        c = doc['claims']
        if doc['kind'] == 'focused':
            records(c['records'])
            require(c['records'], 'Focused evidence requires named records')
        if doc['kind'] == 'review':
            require(isinstance(c['findings'], list), 'Findings must be a list')
            for finding in c['findings']:
                fields(finding, 'id detail', 'finding')

    unresolved, findings, resolutions, latest = [], [], [], []
    def linked(identifier, kind):
        text(identifier)
        require(identifier in docs and docs[identifier]['kind'] == kind, 'Missing/wrong-kind linked reference')
        return docs[identifier]

    for identifier, doc in docs.items():
        kind, c = doc['kind'], doc['claims']
        if kind == 'focused':
            fields(c, 'status records limitations', kind)
            require(c['status'] in STATUSES, 'Invalid focused status')
            records(c['records']); strings(c['limitations'])
            if c['status'] != 'PASS' or any(r['status'] != 'PASS' for r in c['records']):
                unresolved.append(identifier + ': focused nonpass/partial/active claim')
        elif kind == 'review':
            fields(c, 'status findings limitations', kind)
            require(c['status'] in ('COMPLETE', 'PARTIAL'), 'Invalid review status')
            strings(c['limitations'])
            require(isinstance(c['findings'], list), 'Findings must be a list')
            seen = set()
            for f in c['findings']:
                fields(f, 'id detail', 'finding'); text(f['id']); text(f['detail'])
                require(f['id'] not in seen, 'Duplicate finding ID'); seen.add(f['id'])
                findings.append({'review': identifier, **f})
            if c['status'] != 'COMPLETE':
                unresolved.append(identifier + ': partial review')
        elif kind == 'resolution':
            fields(c, 'review finding status detail proofs', kind)
            text(c['finding']); text(c['detail']); strings(c['proofs'], empty=False)
            review = linked(c['review'], 'review')
            require(any(f['id'] == c['finding'] for f in review['claims']['findings']), 'Unknown finding')
            require(covers(doc['scope'], review['scope']), 'Resolution scope excludes review')
            require(c['status'] in ('RESOLVED', 'UNRESOLVED'), 'Invalid resolution status')
            for proof in c['proofs']:
                p = linked(proof, 'focused')
                require(p['subject'] == doc['subject'] and covers(p['scope'], doc['scope']), 'Resolution proof binding differs')
                require(p['claims']['status'] == 'PASS' and all(r['status'] == 'PASS' for r in p['claims']['records']),
                        'Resolution requires passing focused proof claims')
            require(not any((r['review'], r['finding']) == (c['review'], c['finding']) for r in resolutions),
                    'Conflicting/duplicate resolution')
            resolutions.append({'reference': identifier, **c})
        elif kind == 'qualification':
            fields(c, 'records openGates limitations', kind)
            records(c['records']); strings(c['openGates']); strings(c['limitations'])
            if c['openGates'] or any(r['status'] != 'PASS' for r in c['records']):
                unresolved.append(identifier + ': retained nonpass records or open gates')
        elif kind == 'latest':
            fields(c, 'status terminal workerActive observation limitations', kind)
            require(c['status'] in STATUSES and type(c['terminal']) is bool and type(c['workerActive']) is bool,
                    'Invalid latest state')
            strings(c['limitations'])
            base = (manifest_path.parent / refs[identifier]['path']).resolve().parent
            observation = inputs.artifact(c['observation'], base)
            require(c['observation']['format'] == 'json' and isinstance(observation, dict), 'Latest observation must be JSON')
            require(observation.get('schema') == 'tvp.latest-verification/v1', 'Existing latest verification observation required')
            s = observation.get('subject')
            require(isinstance(s, dict) and isinstance(s.get('snapshot'), dict), 'Missing latest subject snapshot')
            require(isinstance(s['snapshot'].get('locked'), dict), 'Missing latest locked identity')
            observed_subject = {'path': s.get('source'), 'revision': s.get('revision'), 'tree': s.get('tree'),
                                'narHash': s['snapshot'].get('locked', {}).get('narHash')}
            require(observed_subject == doc['subject'], 'Latest observation source mismatch')
            require(s['snapshot'].get('path') == s.get('source') and s['snapshot'].get('revision') == s.get('revision')
                    and s['snapshot'].get('locked', {}).get('rev') == s.get('revision'), 'Latest snapshot identity mismatch')
            require(observation.get('result') == c['status'] and observation.get('full') is False
                    and observation.get('machineReady') is False and observation.get('mergeEligible') is False,
                    'Latest observation result/limits mismatch')
            if c['status'] != 'PASS' or not c['terminal'] or c['workerActive']:
                unresolved.append(identifier + ': latest failed/active/partial')
            latest.append({'reference': identifier, 'observation': observation})
        elif kind == 'lineage':
            fields(c, 'from to mode proofs resolutions reason', kind)
            subject(c['from']); subject(c['to']); text(c['reason'])
            require(c['to'] == doc['subject'] and c['from'] != c['to'], 'Invalid lineage endpoints')
            require(c['mode'] in ('repair', 'proof-reuse'), 'Invalid lineage mode')
            strings(c['proofs'], empty=False); strings(c['resolutions'])
            for proof in c['proofs']:
                p = linked(proof, 'focused')
                require(p['subject'] == c['to'] and covers(p['scope'], doc['scope']), 'Lineage proof binding differs')
                require(p['claims']['status'] == 'PASS' and all(r['status'] == 'PASS' for r in p['claims']['records']),
                        'Lineage requires passing focused proof claims')
            require(c['mode'] != 'repair' or c['resolutions'], 'Repair requires explicit finding resolutions')
            for resolution in c['resolutions']:
                r = linked(resolution, 'resolution')
                review = linked(r['claims']['review'], 'review')
                require(r['subject'] == c['to'] and review['subject'] == c['from']
                        and r['claims']['status'] == 'RESOLVED' and covers(r['scope'], doc['scope']),
                        'Repair resolution endpoints/scope differ')
        elif kind == 'protection':
            fields(c, 'domain files', kind); text(c['domain'])
            require(isinstance(c['files'], list) and c['files'], 'Protection files required')
            seen = set()
            for row in c['files']:
                fields(row, 'path sha256', 'protected file')
                require(isinstance(row['path'], str) and Path(row['path']).is_absolute(), 'Absolute protection path required')
                require(row['path'] not in seen, 'Duplicate protected path'); seen.add(row['path'])
                inputs.read(row['path'], row['sha256'], parse=False)

    for identifier, ref in refs.items():
        current, visited = ref['subject'], [ref['subject']]
        require(ref['kind'] not in ('resolution', 'protection') or current == m['subject'], 'Final subject required')
        for step in ref['lineage']:
            require(ref['kind'] in ('focused', 'review', 'qualification', 'latest', 'lineage'), 'Lineage not allowed')
            link = linked(step, 'lineage')
            c = link['claims']
            require(c['from'] == current and covers(link['scope'], ref['scope']), 'Broken lineage/scope chain')
            current = c['to']
            require(current not in visited, 'Cyclic lineage'); visited.append(current)
        require(current == m['subject'], 'Source mismatch without complete explicit lineage')
    for finding in findings:
        resolution = next((r for r in resolutions if (r['review'], r['finding']) ==
                           (finding['review'], finding['id'])), None)
        finding['resolution'] = resolution
        if not resolution or resolution['status'] != 'RESOLVED':
            unresolved.append(finding['review'] + '/' + finding['id'] + ': unresolved finding')
    missing = [{'family': family, 'kind': kind} for family in sorted(m['scope']['families']) for kind in REQUIRED
               if not any(r['kind'] == kind and family in r['scope']['families'] for r in refs.values())]
    # Reporting is never an admission authority, even with all expected receipts.
    return {'schema': 'tvp.batch-report/v1', 'subject': m['subject'], 'scope': m['scope'],
            'state': 'UNRESOLVED' if unresolved else ('INCOMPLETE' if missing else 'COLLECTED'),
            'machineReady': False, 'mergeEligible': False, 'full': False, 'freshExecutionCertified': False,
            'observed': {'inputs': inputs.hashes, 'referenceBindingsChecked': sorted(refs)},
            'claims': {k: docs[k] for k in sorted(docs)}, 'latestObservations': latest,
            'findings': findings, 'missing': missing, 'unresolved': sorted(unresolved),
            'openGates': ['HARDENING-GATE-1'], 'limitations': LIMITS}


def summary(report):
    return '\n'.join([
        'TVP batch receipt report: ' + report['state'],
        'JSON SHA256: ' + hashlib.sha256(encoded(report)).hexdigest(),
        'Source: ' + json.dumps(report['subject'], sort_keys=True),
        'Scope: ' + json.dumps(report['scope'], sort_keys=True),
        'machineReady=false mergeEligible=false full=false freshExecutionCertified=false',
        'Missing: ' + json.dumps(report['missing'], sort_keys=True),
        'Findings: ' + json.dumps(report['findings'], sort_keys=True),
        'Unresolved: ' + json.dumps(report['unresolved']),
        'Evidence claims (including raw nonpasses and limitations): ' + json.dumps(report['claims'], sort_keys=True),
        'Open gates: HARDENING-GATE-1', *report['limitations'], '',
    ])


def publish(report, output, summary_path=None):
    inputs = report['observed']['inputs']
    outputs = [(Path(output).absolute(), encoded(report))]
    if summary_path is not None:
        outputs.append((Path(summary_path).absolute(), summary(report).encode()))
    require(len({p.resolve() for p, _ in outputs}) == len(outputs), 'Outputs alias each other')
    for path, data in outputs:
        require(str(path.resolve()) not in inputs, 'Output aliases an input')
        if path.exists() or path.is_symlink():
            require(not path.is_symlink() and path.read_bytes() == data, 'Conflicting report already exists')
    atomic_report(output, report, inputs)
    if summary_path is not None:
        path, data = outputs[1]
        if path.exists() or path.is_symlink():
            require(not path.is_symlink() and path.read_bytes() == data, 'Conflicting report already exists')
            return
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
                temporary = stream.name
                stream.write(data); stream.flush(); os.fsync(stream.fileno())
            os.link(temporary, path)
        finally:
            if temporary:
                os.unlink(temporary)


def add_parser(commands):
    parser = commands.add_parser('report', help=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--summary', type=Path)


def dispatch(args):
    report = collect(args.manifest)
    publish(report, args.output, args.summary)
    print(json.dumps({'state': report['state'], 'output': str(args.output), 'machineReady': False,
                      'mergeEligible': False, 'full': False, 'freshExecutionCertified': False}))
    return 0
