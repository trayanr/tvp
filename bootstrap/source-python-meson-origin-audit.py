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
    prior = importlib.import_module('source-cmake-origin-audit').run()
    if prior['failures']:
        raise ValueError('Prior construction audit failed')
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file',
                         str(ROOT / 'source-python-meson-tests.nix'), 'python', 'meson',
                         'helperConsumer', 'pythonCompatibility', 'sourceOverridePython', 'sourceOverrideMeson')
    graph = raw.get('derivations', raw)
    normalized = copy.deepcopy(graph)
    roles = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let f=import {ROOT}/source-python-meson.nix {{}};
      in {{ shell="${{f.composition.bash}}/bin/bash";
            coreutils=toString f.composition.coreutils; }}''')
    producers = {audit.store_path(o.get('path', n['env'][name])): audit.store_path(d)
                 for d, n in graph.items() for name, o in n['outputs'].items()}
    profiles, failures = {}, []
    stage_names = {'python-build-3.12.5', 'meson-1.12.1', 'source-python-consumer-1',
                   'source-meson-consumer-1', 'source-meson-helper-consumer-1',
                   'source-meson-traced-tools-1', 'source-python-override-3.12.5',
                   'source-meson-override-1.12.1', 'openssl-3.0.21', 'source-python-compatibility-1'}
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
            checks_valid = True
            valid = (checks_valid and name in stage_names and n['builder'] == roles['shell']
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
            failures.append('Invalid source Python/Meson runner: ' + full)
            continue
        profiles[full] = dict(kind=kind, actualEnvironment=graph[drv]['env'],
                             actualStructuredAttrs=graph[drv].get('structuredAttrs'),
                             commandSHA256=hashlib.sha256(json.dumps(n['args']).encode()).hexdigest(),
                             substitutionPolicy='Nix default; execution recorded separately')
        n['env']['PATH'] = ''; n['env']['allowSubstitutes'] = ''
    fixture = audit.nix_json('eval', '--json', '--impure', '--expr',
        f'"${{{ROOT}/../pkgs/build-tools/meson/tests/fixtures}}"')
    local = ROOT / '../pkgs/build-tools/meson/tests/fixtures'
    def digest_tree(root):
        result = {}
        for path in sorted(Path(root).rglob('*')):
            if path.is_symlink(): raise ValueError('Fixture symlink')
            if path.is_file():
                data = path.read_bytes()
                if data.startswith((b'\x7fELF', b'MZ')): raise ValueError('Fixture executable')
                result[str(path.relative_to(root))] = hashlib.sha256(data).hexdigest()
        return result
    fixture_hashes = digest_tree(Path(fixture))
    assert fixture_hashes == digest_tree(local)
    # Prior auditor has just checked these exact data directories. Their source
    # classification grants no builder/interpreter/runtime executable permission.
    for n in normalized.values():
        srcs = n.get('inputs', {}).get('srcs', [])
        for src in srcs[:]:
            p = audit.store_path(src)
            if (p in prior['sourceData'] and Path(p).is_dir()) or p == fixture:
                srcs.remove(src)
    pins = copy.deepcopy(prior['constructionPins'])
    pins['archives'] += [dict(url=p.get('url', p.get('urls', [None])[0]), hash=p['hash']) for p in json.loads((ROOT / 'source-python-meson-sources.json').read_text()).values()]
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
    result['sourceData'] = prior['sourceData'] | result['sourceData'] | {fixture: dict(origin='owned-source-or-nix-generated-text', role='exact-owned-Meson-fixtures; no executable permission', files=fixture_hashes)}
    result['ownedRunnerProfile'] = prior['ownedRunnerProfile'] | profiles
    result['roles'] = roles
    return result


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
