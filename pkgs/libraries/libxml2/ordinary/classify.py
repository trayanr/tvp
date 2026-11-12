"""Read-only source-bound inspection and fail-closed acceptance of CHECKER output.

protocolValid describes recognition, never qualification. Unsupported corpus and
outer reports remain gaps even when individual bodies are source-recognized.
All dependencies are explicit CLI/API inputs; no sibling imports or host tools.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import tarfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def regular(path, single_link=True):
    state = path.lstat()
    if not stat.S_ISREG(state.st_mode) or (single_link and state.st_nlink != 1):
        raise ValueError(('special/aliased record', str(path)))
    return path.read_bytes()


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(('duplicate JSON key', key))
        value[key] = item
    return value


def read_record(path, single_link=True):
    value = json.loads(regular(Path(path), single_link), object_pairs_hook=unique)
    if not isinstance(value, dict):
        raise ValueError('record must be an object')
    return value


def directory(path):
    if not stat.S_ISDIR(path.lstat().st_mode) or path != path.resolve(strict=True):
        raise ValueError(('canonical directory required', str(path)))


def keys(value, expected):
    if set(value) != set(expected):
        raise ValueError(('record keys', sorted(value), sorted(expected)))


def command_record(path, fields):
    record = read_record(path)
    keys(record, fields)
    if (type(record['exit']) is not int or not isinstance(record['argv'], list)
            or not record['argv'] or any(type(a) is not str or not a for a in record['argv'])):
        raise ValueError('invalid command argv/exit types')
    return record


class ConfiguredMacros(dict):
    """Active definitions plus names explicitly present in the header."""
    def __init__(self):
        super().__init__()
        self.known = set()


def feature_macros(text):
    """Interpret only the literal configured-header language we support.

    In particular a define under #if 0 is absent. Unknown expressions/directives
    are errors, including in inactive branches; no compiler or guessed values.
    """
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    active, stack, macros = True, [], ConfiguredMacros()
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith('#'):
            if line:
                raise ValueError(('unsupported configured header text', line))
            continue
        directive = re.fullmatch(r'#\s*(\w+)(?:\s+(.*?))?\s*', line)
        if not directive:
            raise ValueError('unsupported header directive')
        op, arg = directive.group(1), directive.group(2) or ''
        if op in ('if', 'ifndef'):
            if op == 'if' and arg in ('0', '1'):
                condition = arg == '1'
            elif op == 'ifndef' and arg in ('__XML_VERSION_H__', '__XML_VERSION_H'):
                condition = arg not in macros
            else:
                raise ValueError(('unsupported header conditional', line))
            stack.append((active, condition, False))
            active = active and condition
        elif op == 'else':
            if not stack or stack[-1][2] or arg:
                raise ValueError('unbalanced header else')
            parent, condition, _ = stack[-1]
            stack[-1] = parent, condition, True
            active = parent and not condition
        elif op == 'endif':
            if not stack or arg:
                raise ValueError('unbalanced header endif')
            active = stack.pop()[0]
        elif op == 'define':
            match = re.fullmatch(r'(\w+)(?:\s+(.*))?', arg)
            if not match:
                raise ValueError(('unsupported header define', arg))
            name, value = match.groups()
            macros.known.add(name)
            if active:
                if name in macros:
                    raise ValueError(('duplicate active macro', name))
                macros[name] = value or ''
        elif op == 'undef' and re.fullmatch(r'\w+', arg):
            macros.known.add(arg)
            if active:
                macros.pop(arg, None)
        elif op == 'include' and arg == '<libxml/xmlexports.h>':
            pass  # exports annotations do not set configured feature macros
        else:
            raise ValueError(('unsupported configured header directive', line))
    if stack:
        raise ValueError('unterminated header conditional')
    return macros


def selected_descriptions(source, macros):
    """Select literal testDescriptions entries using a deliberately small grammar."""
    body = source.split('testDescriptions[] = {', 1)[1].split('\n};', 1)[0]
    active, stack, result = True, [], []
    def defined(name):
        if name not in macros.known:
            raise ValueError(('unbound source predicate', name))
        return name in macros
    for line in body.splitlines():
        line = line.strip()
        if line.startswith('#'):
            if line.startswith('#ifdef '):
                condition = defined(line[7:])
            elif line.startswith('#ifndef '):
                condition = not defined(line[8:])
            elif line.startswith('#if '):
                expr = line[4:]
                # Only conjunctions of defined symbols; no eval/host interpreter.
                terms = expr.split(' && ')
                if not all(re.fullmatch(r'defined\(\w+\)', t) for t in terms):
                    raise ValueError(('unsupported description condition', expr))
                conditions = [defined(t[8:-1]) for t in terms]
                condition = all(conditions)
            elif line == '#endif':
                if not stack:
                    raise ValueError('unbalanced description conditional')
                active = stack.pop()
                continue
            else:
                raise ValueError(('unsupported description directive', line))
            stack.append(active)
            active = active and condition
        elif active:
            m = re.match(r'\{\s*"([^"\\]+)"\s*,', line)
            if m:
                result.append('## '+m[1]+'\n')
    if stack or not result:
        raise ValueError('unrecognized description table')
    return ''.join(result)


def source_contract(archive, version, contracts):
    """Recompute archive and selected role hashes, never trust a release label."""
    entry = contracts['sources'].get(version)
    if not entry or digest(regular(archive, single_link=False)) != entry['archiveSha256']:
        raise ValueError('SOURCE_BINDING_GAP: unknown effective source archive')
    sources = {}
    with tarfile.open(archive) as tar:
        members = {}
        prefix = 'libxml2-'+version+'/'
        for member in tar.getmembers():
            if member.name in members:
                raise ValueError('duplicate archive member')
            members[member.name] = member
        for role, expected in entry['roles'].items():
            member = members.get(prefix+role)
            if member is None or not member.isfile():
                raise ValueError(('missing source role', role))
            body = tar.extractfile(member).read()
            if digest(body) != expected:
                raise ValueError(('source role mismatch', role))
            sources[role] = body.decode('latin-1')  # upstream C comments can be Latin-1
        corpus = sorted(m.name.removeprefix(prefix) for m in members.values()
                        if m.isfile() and m.name.startswith(prefix) and
                        m.name.removeprefix(prefix).startswith(('test/', 'result/')))
        if len(corpus) != entry['corpusMembers'] or digest(json.dumps(corpus).encode()) != entry['corpusInventorySha256']:
            raise ValueError('source corpus manifest mismatch')
    group = next(g for g in contracts['groups'] if g['id'] == entry['protocol'])
    if version not in group['versions']:
        raise ValueError('source protocol version mismatch')
    return entry, group, sources


def framed_events(body, patterns):
    if not body:
        return []
    delimiter = '\n------------\n'
    if not body.startswith(delimiter):
        raise ValueError('unframed operational log')
    result = []
    for block in body.split(delimiter)[1:]:
        first, newline, tail = block.partition('\n')
        if not newline or not any(re.fullmatch(p, first) for p in patterns):
            raise ValueError(('unknown operational event', first))
        result.append({'event': first, 'diagnosticBytes': len(tail.encode()), 'diagnosticSha256': digest(tail.encode())})
    return result


def log_patterns(source):
    # Source-selected printf format strings, anchored at the FIRST frame line.
    formats = re.findall(r'test_log\s*\(\s*"([^"\n]*(?:\\.[^"\n]*)*)"', source)
    patterns = []
    for fmt in formats:
        literal = fmt.replace('\\n', '\n').split('\n', 1)[0]
        pieces = re.split(r'(%(?:ld|d|s))', literal)
        patterns.append(''.join(r'-?[0-9]+' if x in ('%d', '%ld') else r'.+' if x == '%s' else re.escape(x) for x in pieces))
    return patterns


def summary_body(text, headers):
    if not text.startswith(headers):
        raise ValueError('missing/changed/source-feature header sequence')
    m = re.fullmatch(r'Total ([1-9][0-9]*) tests, no errors\n', text[len(headers):])
    if not m:
        raise ValueError('incomplete/contradictory/nonpositive terminal summary')
    return int(m[1])


def legacy_api_progress(source):
    """Generated API module order and literals, without interpreting C code."""
    driver = re.search(r'static int\s+testlibxml2\(void\)\s*\{(.*?)\n\}', source, re.S)
    if not driver or '#' in driver[1]:
        raise ValueError('unsupported legacy API driver shape')
    calls = re.findall(r'test_ret \+= test_(\w+)\(\);', driver[1])
    if not calls:
        raise ValueError('missing source API module calls')
    progress = []
    for module in calls:
        function = re.search(r'static int\s+test_'+re.escape(module)+r'\(void\)\s*\{(.*?)\n\}', source, re.S)
        if not function:
            raise ValueError('missing API module definition')
        # The progress statement must precede any conditional test bodies.
        prefix = re.match(r'\s*int test_ret = 0;\s*if \(quiet == 0\) printf\("(Testing [^"\\]+)\\n"\);', function[1])
        if not prefix:
            raise ValueError('unsupported API module progress shape')
        progress.append(prefix[1]+'\n')
    return ''.join(progress)


def inspect_unit(name, out, err, group, sources, macros, bodies):
    result = {'protocolValid': True, 'bodySuccess': False, 'operationalNonpasses': [], 'coverageGaps': []}
    gaps, nonpasses = result['coverageGaps'], result['operationalNonpasses']
    def exact(expected_out, expected_err=''):
        if (out, err) != (expected_out, expected_err):
            raise ValueError('unrecognized stdout/stderr body')
        result['bodySuccess'] = True
    if name == 'testchar':
        exact(bodies['testchar'])
    elif name == 'testdict':
        exact('' if group['testdictProtocol'] == 'silent' else 'dictionary tests succeeded 20000 strings\n')
    elif name == 'testapi':
        if group['testapiProtocol'] == 'silent':
            exact('')
        else:
            progress = legacy_api_progress(sources['testapi.c'])
            if err or not out.startswith(progress) or not re.fullmatch(r'Total: [1-9][0-9]* functions, [1-9][0-9]* tests, 0 errors\n', out[len(progress):]):
                raise ValueError('unrecognized legacy API progress/total/leak tail')
            result['bodySuccess'] = True
    elif name in ('testModule', 'testcatalog', 'testThreads'):
        macro = {'testModule': 'LIBXML_MODULES_ENABLED', 'testcatalog': 'LIBXML_CATALOG_ENABLED', 'testThreads': 'LIBXML_THREAD_ENABLED'}[name]
        if macro not in macros:
            gaps.append('FEATURE_DISABLED: '+macro)
            if name == 'testModule':
                if (out, err) != ('./testModule : Module support not compiled in\n', ''):
                    raise ValueError('unrecognized disabled module body')
            elif out or err:
                raise ValueError('unsupported disabled feature body')
        else:
            exact('Success!\n' if name == 'testModule' else '')
    elif name == 'testparser':
        version = re.search(r'"([0-9.]+)"', macros.get('LIBXML_DOTTED_VERSION', ''))
        if not version:
            raise ValueError('missing configured version')
        if version[1] == '2.15.3':
            needed = {'LIBXML_READER_ENABLED', 'LIBXML_SCHEMAS_ENABLED', 'LIBXML_RELAXNG_ENABLED'}
            if not needed <= macros.keys():
                gaps.append('PARSER_FEATURE_SHAPE_GAP')
                raise ValueError('unsupported partial negative parser probes')
            exact('', bodies['parser21503'])
        else:
            exact('')
            gaps.append('PARSER_BOUNDARY_CAPTURE_GAP')
    elif name in ('runtest', 'testrecurse'):
        result['tests'] = summary_body(out, selected_descriptions(sources[name+'.c'], macros))
        if err:
            nonpasses.append({'code': 'UNRECOGNIZED_DIAGNOSTIC', 'bytes': len(err.encode()), 'sha256': digest(err.encode())})
            result['protocolValid'] = False
        else:
            result['bodySuccess'] = True
        gaps.append('EXECUTED_CORPUS_COVERAGE_GAP: aggregate total does not prove every source glob executed')
    elif name == 'runxmlconf':
        zero = 'Ran 0 tests, no errors\nTotal 0 tests, no errors\n'
        missing = ('./xmlconf/xmlconf.xml is missing \n  you need to fetch and extract the\n'
                   '  latest XML Conformance Test Suites\n  http://www.w3.org/XML/Test/xmlts20080827.tar.gz\n'
                   '  see http://www.w3.org/XML/Test/ for information\n')
        if out == zero and err == missing:
            gaps.append('W3C_CORPUS_MISSING: zero tests; historical failures unrun/unwaived')
            result['tests'] = 0
        else:
            gaps.append('W3C_IDENTITY_COVERAGE_GAP: actual corpus/skip/failure identities required')
            raise ValueError('unsupported W3C body; counts never establish identity')
    elif name == 'runsuite':
        suite_body(result, out, err, group)
    else:
        raise ValueError('unsupported command body')
    return result


def suite_body(result, out, err, group):
    """Narrow source-observed six-section protocol; preserve reset counts."""
    expected = group['runsuiteSourceExpectedXsdErrors']
    pattern = (r'## XML Schemas datatypes test suite from James Clark\n'
               r'Ran ([1-9][0-9]*) tests, '+str(expected)+r' errors, 0 leaks\n'+str(expected)+r' errors were expected\n'
               r'## Relax NG test suite from James Clark\nRan ([1-9][0-9]*) tests, no errors\n'
               r'## Relax NG test suite for libxml2\nRan ([1-9][0-9]*) tests, no errors\n')
    pattern += r'Ran 0 tests \(0 schemata\), no errors\n' * 3
    pattern += r'Total ([1-9][0-9]*) tests, no errors\n'
    m = re.fullmatch(pattern, out)
    paths = ['NISTXMLSchemaDatatypes', 'SunXMLSchema1-0-20020116', 'MSXMLSchema1-0-20020116']
    if not m or err != ''.join('Failed to parse xstc/Tests/Metadata/'+p+'.testSet\n' for p in paths):
        raise ValueError('unsupported/contradictory runsuite sections or stderr')
    counts = list(map(int, m.groups()))
    if sum(counts[:3]) != counts[3]:
        raise ValueError('runsuite total contradicts section counts')
    result['tests'] = counts[3]
    result['sourceResetErrors'] = expected
    result['operationalNonpasses'].append({'code': 'SOURCE_RESET_ERRORS_UNWAIVED', 'count': expected})
    result['coverageGaps'].extend('XSTC_METADATA_MISSING_ZERO_GROUP: '+p for p in paths)


def inspect(root, version, contracts_path=None, binding_path=None, artifact_root=None):
    report = {'schema': 1, 'reportKind': 'structural-inspection-not-test-receipt',
              'protocolValid': False, 'strictPass': False, 'units': {},
              'operationalNonpasses': [], 'coverageGaps': [], 'structuralErrors': []}
    gaps, errors = report['coverageGaps'], report['structuralErrors']
    if contracts_path is None or binding_path is None:
        gaps.append('SOURCE_FEATURE_BINDING_GAP: explicit contracts and effective binding required')
        return report
    try:
        contracts = read_record(contracts_path, single_link=False)
        binding = binding_path if isinstance(binding_path, dict) else read_record(binding_path)
        keys(binding, ['schema', 'version', 'source', 'sourceCwd', 'system', 'features', 'runtime', 'make', 'bash', 'python', 'commandCaptureHelper'])
        if type(binding['schema']) is not int or type(contracts['schema']) is not int or binding['schema'] != 1 or contracts['schema'] != 1 or binding['version'] != version:
            raise ValueError('binding schema/version mismatch')
        if binding['system'] != 'x86_64-linux' or binding['sourceCwd'] != '/build/workspace/source':
            raise ValueError('unsupported system/source cwd binding')
        artifact = Path(artifact_root) if artifact_root is not None else Path('/missing-artifact-binding')
        root = Path(root)
        directory(root)
        if root != artifact/'nix-support/upstream-raw':
            raise ValueError('raw root does not belong to bound artifact')
        entry, group, sources = source_contract(Path(binding['source']), version, contracts)
        header = artifact/'include/libxml2/libxml/xmlversion.h'
        if header != header.resolve(strict=True):
            raise ValueError('configured header path alias')
        header_bytes = regular(header, single_link=False)
        macros = feature_macros(header_bytes.decode())
        if macros.get('LIBXML_DOTTED_VERSION') != '"'+version+'"':
            raise ValueError('configured header/source version mismatch')
        # These effective recipe features have direct configured-header meanings.
        feature_names = {'xpath':'XPATH', 'lzma':'LZMA', 'icu':'ICU', 'iconv':'ICONV', 'http':'HTTP'}
        for field, macro in feature_names.items():
            expected = binding['features'].get(field)
            if type(expected) is not bool or expected != ('LIBXML_'+macro+'_ENABLED' in macros):
                raise ValueError(('effective feature/header mismatch', field))
        if binding['features'].get('doCheck') is not True or not isinstance(binding['runtime'], dict):
            raise ValueError('effective runtime/check binding missing')
        keys(binding['runtime'], ['shell', 'libraries'])
        if type(binding['runtime']['shell']) is not str or not binding['runtime']['shell'] or not isinstance(binding['runtime']['libraries'], list) or any(type(x) is not str or not x for x in binding['runtime']['libraries']):
            raise ValueError('effective runtime binding types')
        macros.known.add('__linux__')
        macros['__linux__'] = ''  # bound target above; never inferred from host
        if digest(regular(Path(binding['commandCaptureHelper']), single_link=False)) != contracts['captureCommandSha256']:
            raise ValueError('unsupported command capture adapter/hash-counter definition')
        report['binding'] = {'version': version, 'source': binding['source'], 'archiveSha256': entry['archiveSha256'],
                             'sourceRoleSha256': entry['roles'], 'protocol': group['id'],
                             'headerSha256': digest(header_bytes), 'activeMacros': macros,
                             'effectiveFeatures': binding['features'], 'runtime': binding['runtime'],
                             'checkerArgv': checker_inventory(group), 'fuzz': entry['fuzz'],
                             'outerChecks': group['unwrappedRootChecks'], 'sourceCorpusMembers': entry['corpusMembers']}
        outer = command_record(root/'exit.json', ['argv', 'exit'])
        argv = outer['argv']
        expected_tail = ['SHELL='+binding['bash']+'/bin/bash',
                         'CHECKER='+binding['python']+'/bin/python3 -B '+binding['commandCaptureHelper'], 'check']
        if len(argv) != 5 or argv[0] != binding['make']+'/bin/make' or not re.fullmatch(r'-j[1-9][0-9]*', argv[1]) or argv[2:] != expected_tail:
            raise ValueError('outer argv/tool identity mismatch')
        if outer['exit']:
            report['operationalNonpasses'].append({'code':'OUTER_EXIT', 'exit':outer['exit']})
        report['outerStdoutSha256'] = digest(regular(root/'stdout'))
        required_logs = {'runxmlconf.log'}
        if any(row[0] == 'runsuite' for row in group['checkerInventory']):
            required_logs.add('runsuite.log')
        allowed_logs = {'runsuite.log', 'runxmlconf.log', 'runtest.log', 'test-suite.log'}
        names = {p.name for p in root.iterdir()}
        if not {'commands','stdout','exit.json'} | required_logs <= names or names - ({'commands','stdout','exit.json'} | allowed_logs):
            raise ValueError('missing/unknown raw root records')
        logs = {n:regular(root/n).decode('utf-8') for n in names & allowed_logs}
        commands = root/'commands'
        directory(commands)
        inventory = checker_inventory(group)
        observed = []
        for unit in sorted(commands.iterdir()):
            directory(unit)
            if {p.name for p in unit.iterdir()} != {'exit.json','stdout','stderr'}:
                raise ValueError('incomplete/unknown command records')
            record = command_record(unit/'exit.json', ['argv','cwd','exit'])
            if type(record['cwd']) is not str or record['cwd'] != binding['sourceCwd']:
                raise ValueError('command source cwd mismatch')
            identity = digest(json.dumps([record['cwd'],record['argv']]).encode())+'-0'
            if unit.name != identity or record['argv'] not in inventory or record['argv'] in observed:
                raise ValueError('extra/duplicate/argv/hash-counter mismatch')
            observed.append(record['argv'])
            name = record['argv'][0][2:]
            out, err = (regular(unit/n).decode('utf-8') for n in ('stdout','stderr'))
            try:
                outcome = inspect_unit(name,out,err,group,sources,macros,contracts['bodies'])
            except (ValueError,IndexError) as error:
                outcome = {'protocolValid':False,'bodySuccess':False,'operationalNonpasses':[],
                           'coverageGaps':['BODY_REPORT_GAP: '+str(error)]}
            outcome.update({'argv':record['argv'],'exit':record['exit'], 'stdoutSha256':digest(out.encode()),'stderrSha256':digest(err.encode())})
            if record['exit']:
                outcome['bodySuccess'] = False
                outcome['operationalNonpasses'].append({'code':'COMMAND_EXIT','exit':record['exit']})
            report['units'][name] = outcome
        if sorted(observed) != sorted(inventory):
            errors.append('missing CHECKER units')
        for name, body in logs.items():
            if name == 'runsuite.log':
                events = framed_events(body, log_patterns(sources['runsuite.c']))
                report['runsuiteEvents'] = events
                report['operationalNonpasses'].extend({'code':'RUNSUITE_EVENT',**event} for event in events)
                suite = report['units'].get('runsuite', {})
                reset = suite.get('sourceResetErrors')
                if reset is not None:
                    xsd = sum(e['event'].startswith('Failed to validate valid instance line ') for e in events)
                    if xsd != reset:
                        errors.append('runsuite reset/log counter contradiction')
            elif body:
                gaps.append('LOG_BODY_GAP: '+name)
        gaps.append('OUTER_REPORT_GAP: complete Make/script/catalog/SGML/fuzzer body and per-command exits unsupported')
        gaps.append('CORPUS_EXECUTION_GAP: source member inventory is not proof of executed corpus coverage')
        report['protocolValid'] = not errors and all(u['protocolValid'] for u in report['units'].values())
        report['strictPass'] = (report['protocolValid'] and not gaps and not report['operationalNonpasses']
                                and all(u['bodySuccess'] and not u['coverageGaps'] and not u['operationalNonpasses'] for u in report['units'].values()))
    except (ValueError, OSError, KeyError, TypeError, StopIteration, tarfile.TarError) as error:
        errors.append(str(error))
        gaps.append('SOURCE_OR_REPORT_BINDING_GAP')
    return report


def checker_inventory(group):
    return [['./'+name] + (['-d','./xmlconf'] if arg else []) for name,arg in group['checkerInventory']]


def classify(root, version, contracts_path=None, binding_path=None, artifact_root=None):
    report = inspect(root,version,contracts_path,binding_path,artifact_root)
    if not report['strictPass']:
        raise ValueError(('strict upstream nonpass UNWAIVED', report))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('version')
    parser.add_argument('--contracts', type=Path, required=True)
    binding = parser.add_mutually_exclusive_group(required=True)
    binding.add_argument('--binding', type=Path)
    binding.add_argument('--binding-json')
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--inspect', action='store_true', help='emit structural report; never a test receipt')
    args = parser.parse_args()
    report = inspect(args.root,args.version,args.contracts, json.loads(args.binding_json, object_pairs_hook=unique) if args.binding_json else args.binding, args.artifact)
    print(json.dumps(report,indent=2,sort_keys=True))
    return 0 if args.inspect or report['strictPass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
