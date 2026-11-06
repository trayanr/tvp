"""Opt-in extension; independently audit old and new graphs before their union."""
import copy
import hashlib
import importlib
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent


def run():
    prior = importlib.import_module('source-native-compiler-origin-audit').run()
    if prior['failures']:
        raise ValueError('Prior construction audit failed')
    assert len(prior['nodes']) == 893 and len(prior['ownedRunnerProfile']) == 507
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file',
                         str(ROOT / 'source-full-gcc-prerequisite-tests.nix'), 'consumer', 'upstream')
    graph = raw.get('derivations', raw)
    normalized = copy.deepcopy(graph)
    roles = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let f=import {ROOT}/source-native-compiler.nix {{}};
      in {{ shell="${{f.composition.bash}}/bin/bash";
            coreutils=toString f.composition.coreutils; }}''')
    producers = {audit.store_path(o.get('path', n['env'][name])): audit.store_path(d)
                 for d, n in graph.items() for name, o in n['outputs'].items()}
    profiles, failures = {}, []
    stage_names = {'isl-0.28', 'libxcrypt-4.5.2', 'which-2.21', 'ncurses-6.6',
                   'texinfo-7.1', 'source-full-gcc-prerequisite-consumers-1',
                   'source-full-gcc-prerequisite-upstream-1'}
    for drv, n in normalized.items():
        full = audit.store_path(drv)
        if full in prior['ownedRunnerProfile']:
            n['env']['PATH'] = ''; n['env']['allowSubstitutes'] = ''
            continue
        if full in prior['nodes']:
            continue
        deps = {audit.store_path(p) for p in n.get('inputs', {}).get('drvs', {})}
        name = n.get('name', n['env'].get('name', ''))
        if 'structuredAttrs' in n:
            data = n['structuredAttrs']
            expected_fields = {'builder', 'name', 'outputs', 'stageInputs', 'system'}
            valid = (name in stage_names and n['builder'] == roles['shell']
                     and n['args'][0] == '-euc'
                     and n['args'][1].startswith('source "$NIX_ATTRS_SH_FILE"\n')
                     and set(data) == expected_fields
                     and all(producers.get(p) in deps for p in data['stageInputs']))
            kind = 'owned-structured-stage'
        elif name == 'tvp-build-step-runner' or name.startswith('tvp-step-'):
            env = n['env']
            valid = (n['builder'] == roles['shell']
                     and n['args'] == ['-euc', roles['coreutils'] + '/bin/cp "$textPath" "$out"']
                     and env.get('passAsFile') == 'text' and env.get('allowSubstitutes') == '1'
                     and 'text' in env and 'PATH' not in env
                     and producers.get(roles['coreutils']) in deps)
            kind = 'owned-text-copy'
        else:
            continue
        if not valid:
            failures.append('Invalid full compiler prerequisite runner: ' + full)
            continue
        profiles[full] = dict(kind=kind, actualEnvironment=graph[drv]['env'],
                             actualStructuredAttrs=graph[drv].get('structuredAttrs'),
                             commandSHA256=hashlib.sha256(json.dumps(n['args']).encode()).hexdigest(),
                             substitutionPolicy='Nix default; execution recorded separately')
        n['env']['PATH'] = ''; n['env']['allowSubstitutes'] = ''
    # Prior auditor has just checked these exact data directories. Their source
    # classification grants no builder/interpreter/runtime executable permission.
    for n in normalized.values():
        srcs = n.get('inputs', {}).get('srcs', [])
        for src in srcs[:]:
            p = audit.store_path(src)
            if (p in prior['sourceData'] and Path(p).is_dir()):
                srcs.remove(src)
    pins = copy.deepcopy(prior['constructionPins'])
    pins['archives'] += [dict(url=p.get('url', p.get('urls', [None])[0]), hash=p['hash']) for p in json.loads((ROOT / 'source-full-gcc-prerequisite-sources.json').read_text()).values()]
    sources = audit.nix_json('eval', '--json', '--impure', '--expr',
        f'let b=import {ROOT} {{}}; in builtins.mapAttrs (_: toString) b.sources')
    result = audit.audit_graph(normalized, sources, pins, prior['stage0Pins'],
                               prior['runtimeForbiddenExecutableRoots'])
    # Compare independent results BEFORE restoring records or forming a union.
    overlapping = set(result['nodes']) & set(prior['nodes'])
    mismatches = [k for k in overlapping if result['nodes'][k] != prior['nodes'][k]]
    failures += ['Prior node changed: ' + k for k in mismatches]
    result['priorPreserved'] = dict(nodes=len(prior['nodes']), profiles=len(prior['ownedRunnerProfile']),
        independentlyCompared=len(overlapping), exact=not mismatches)
    result['failures'] += failures
    result['nodes'] = prior['nodes'] | result['nodes']
    result['sourceData'] = prior['sourceData'] | result['sourceData']
    result['ownedRunnerProfile'] = prior['ownedRunnerProfile'] | profiles
    result['roles'] = roles
    return result


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
