"""Opt-in construction ledger for actual owned-builder endpoints.

The original auditor/profile remains strict and unchanged. Normalize only the
explicit owned runner forms after checking their executable builder/helper edges.
Owned runner primitives permit substitutes by API; this ledger classifies their
source construction definitions, and separate retained build logs prove execution.
"""
import copy
import hashlib
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent
ENDPOINTS = ['a', 'a11', 'libraryB', 'libraryB11', 'consumer', 'override',
             'edited', 'customized', 'mpfrConsumer', 'protocol']


def run():
    old = audit.nix_json('derivation', 'show', '--recursive', '--file', str(ROOT),
                         'gnu-tool-floor', 'gnu-tool-floor-tests', 'gnu-tests',
                         'tests.consumer', 'tests.versions', 'tests.cxx', 'tests.tools',
                         'tests.transitions', 'tests.libc', 'tests.stage-comparison',
                         'tests.gcc10', 'tests.gcc10-archives', 'tests.gcc16', 'tests.prerequisites')
    new = audit.nix_json('derivation', 'show', '--recursive', '--file',
                         str(ROOT / 'gnu-environment-fixtures.nix'), *ENDPOINTS)
    graph = old.get('derivations', old) | new.get('derivations', new)
    normalized = copy.deepcopy(graph)
    b = audit.nix_json('eval', '--json', '--impure', '--expr',
                       f'let b=import {ROOT} {{}}; in {{ bash=toString b.gnu-bash; coreutils=toString b.gnu-tool-floor.gnu-coreutils; }}')
    shell, cp = b['bash'] + '/bin/bash', b['coreutils'] + '/bin/cp'
    profiles, failures = {}, []
    output_drvs = {audit.store_path(o.get('path', n['env'][name])): audit.store_path(d)
                   for d, n in graph.items() for name, o in n['outputs'].items()}
    for drv, node in normalized.items():
        name = node.get('name', node['env'].get('name', ''))
        deps = {audit.store_path(p) for p in node.get('inputs', {}).get('drvs', {})}
        if name.startswith('tvp-private-') and 'structuredAttrs' in node:
            data = node['structuredAttrs']
            deps = {audit.store_path(p) for p in node.get('inputs', {}).get('drvs', {})}
            # Each prepared tool/library root is a real declared producer.
            valid = (node['builder'] == shell and node['args'][0] == '-euc'
                     and node['args'][1].startswith('source "$NIX_ATTRS_SH_FILE"\n')
                     and set(data) == {'builder', 'name', 'outputs', 'stageInputs', 'system'}
                     and all(output_drvs.get(p) in deps for p in data['stageInputs']))
            if not valid:
                failures.append('invalid owned stage profile: ' + drv)
                continue
            profiles[audit.store_path(drv)] = {'kind': 'owned-structured-stage',
                                               'substitutionPolicy': 'Nix default',
                                               'preparedInputs': data['stageInputs']}
            # The runner establishes PATH per prepared step. No host PATH used.
            node['env']['PATH'] = ''
            node['env']['allowSubstitutes'] = ''
        elif name == 'tvp-build-step-runner' or name.startswith('tvp-step-'):
            env = node['env']
            if not (node['builder'] == shell and node['args'] == ['-euc', cp + ' "$textPath" "$out"']
                    and env.get('passAsFile') == 'text' and env.get('allowSubstitutes') == '1'
                    and 'text' in env and 'PATH' not in env
                    and output_drvs.get(b['coreutils']) in deps):
                failures.append('invalid owned script profile: ' + drv)
                continue
            profiles[audit.store_path(drv)] = {'kind': 'owned-text-copy',
                                               'substitutionPolicy': 'allowed by owned runner API'}
            node['env']['PATH'] = ''
            node['env']['allowSubstitutes'] = ''
    for drv, profile in profiles.items():
        original = graph[drv.removeprefix('/nix/store/')]
        profile['actualEnvironment'] = original['env']
        profile['actualStructuredAttrs'] = original.get('structuredAttrs')
        profile['commandSHA256'] = hashlib.sha256(json.dumps(original['args']).encode()).hexdigest()
    sources = audit.nix_json('eval', '--json', '--impure', '--expr',
                            f'let b = import {ROOT} {{}}; in builtins.mapAttrs (_: p: toString p) b.sources')
    provenance = json.loads((ROOT / 'provenance.json').read_text())
    provenance['archives'] += json.loads((ROOT / 'gnu-sources.json').read_text())['archives']
    provenance['archives'] += list(json.loads((ROOT / 'gnu-tool-floor-sources.json').read_text())['archives'].values())
    early = audit.nix_json('derivation', 'show', '--recursive', '--file', str(ROOT), 'compiler', 'libc')
    early_outputs = [audit.store_path(o.get('path', n['env'][name]))
                     for n in early.get('derivations', early).values()
                     for name, o in n['outputs'].items()]
    result = audit.audit_graph(normalized, sources, provenance,
                               json.loads((ROOT / 'stage0-sources.json').read_text()), early_outputs)
    result['failures'] += failures
    result['ownedRunnerProfile'] = profiles
    return result


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
