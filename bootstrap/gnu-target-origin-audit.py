"""Separate opt-in construction ledger. Prior ledgers remain exact and strict."""
import copy
import hashlib
import importlib
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent
ENDPOINTS = ['probe', 'installed', 'consumer', 'override', 'edited', 'customized', 'protocol']


def run():
    prior = importlib.import_module('output-tool-origin-audit').run()
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file',
                         str(ROOT / 'gnu-target-tests.nix'), *ENDPOINTS)
    graph = raw.get('derivations', raw)
    normalized = copy.deepcopy(graph)
    b = audit.nix_json('eval', '--json', '--impure', '--expr',
        f'let b=import {ROOT} {{}}; in {{ bash=toString b.gnu-bash; coreutils=toString b.gnu-tool-floor.gnu-coreutils; }}')
    shell, cp = b['bash'] + '/bin/bash', b['coreutils'] + '/bin/cp'
    producers = {audit.store_path(o.get('path', n['env'][name])): audit.store_path(d)
                 for d, n in graph.items() for name, o in n['outputs'].items()}
    profiles, failures = {}, []
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
            valid = (name.startswith(('tvp-private-', 'tvp-capability-gnu-installed-'))
                and n['builder'] == shell and n['args'][0] == '-euc'
                and n['args'][1].startswith('source "$NIX_ATTRS_SH_FILE"\n')
                and set(data) == {'builder', 'name', 'outputs', 'stageInputs', 'system'}
                and all(producers.get(p) in deps for p in data['stageInputs']))
            kind = 'owned-structured-stage'
        elif name == 'tvp-build-step-runner' or name.startswith('tvp-step-'):
            env = n['env']
            valid = (n['builder'] == shell and n['args'] == ['-euc', cp + ' "$textPath" "$out"']
                and env.get('passAsFile') == 'text' and env.get('allowSubstitutes') == '1'
                and 'text' in env and 'PATH' not in env
                and producers.get(b['coreutils']) in deps)
            kind = 'owned-text-copy'
        else:
            continue
        if not valid:
            failures.append('invalid target owned runner: ' + full)
            continue
        profiles[full] = dict(kind=kind, actualEnvironment=graph[drv]['env'],
            actualStructuredAttrs=graph[drv].get('structuredAttrs'),
            commandSHA256=hashlib.sha256(json.dumps(n['args']).encode()).hexdigest(),
            substitutionPolicy='Nix default; actual execution bound by retained logs')
        n['env']['PATH'] = ''; n['env']['allowSubstitutes'] = ''
    # Authorize exactly the finite probe data tree, never executable origins.
    trees = {}
    expected = {'gnu-target-maps.h', 'gnu-target-rtti.h', 'gnu-target-plugin.cc',
                'gnu-target-rtti.cc', 'gnu-target-locale.cc', 'gnu-cancel.c', 'consumer20.cc',
                'gnu-unwind.cc', 'gnu-plugin.cc'}
    prior_trees = {p: v for p, v in prior['sourceData'].items() if Path(p).is_dir()}
    for n in normalized.values():
        srcs = n.get('inputs', {}).get('srcs', [])
        for short in srcs[:]:
            p = audit.store_path(short)
            if p in prior_trees:
                srcs.remove(short)
            elif Path(p).is_dir() and p.endswith('-tvp-gnu-target-probe-sources'):
                files = list(Path(p).iterdir())
                if {f.name for f in files} != expected:
                    raise ValueError('unexpected probe source tree')
                hashes = {}
                for f in files:
                    if f.is_symlink() or not f.is_file() or f.read_bytes().startswith((b'\x7fELF', b'MZ')):
                        raise ValueError('executable or unexpected source entry')
                    hashes[f.name] = hashlib.sha256(f.read_bytes()).hexdigest()
                trees[p] = dict(origin='owned-source-or-nix-generated-text', filesSHA256=hashes)
                srcs.remove(short)
    sources = audit.nix_json('eval', '--json', '--impure', '--expr',
        f'let b=import {ROOT} {{}}; in builtins.mapAttrs (_: p: toString p) b.sources')
    result = audit.audit_graph(normalized, sources, prior['constructionPins'],
                               prior['stage0Pins'], prior['runtimeForbiddenExecutableRoots'])
    # Preserve old audited records exactly, then add only genuinely new nodes.
    result['nodes'] = prior['nodes'] | {k: v for k, v in result['nodes'].items() if k not in prior['nodes']}
    result['sourceData'] = prior['sourceData'] | result['sourceData'] | trees
    result['ownedRunnerProfile'] = prior['ownedRunnerProfile'] | profiles
    result['failures'] += prior['failures'] + failures
    result['priorPreserved'] = dict(nodes=len(prior['nodes']), profiles=len(prior['ownedRunnerProfile']),
        exact=all(result['nodes'][k] == v for k, v in prior['nodes'].items()))
    result['roles'] = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let b=import {ROOT} {{}}; p=import {ROOT}/gnu-target-profile.nix {{}};
          a=import {ROOT}/gnu-target-environment.nix {{}};
      in {{ build = map toString [b.gnu-cross b.gnu-core-bridge b.gcc-latest b.build-python];
            priorGNUHost = map toString [b.gnu-gcc-unwrapped b.gnu-bash b.gnu-binutils];
            newTarget = map toString [p.libc p.libgcc p.libstdcxx];
            selectedDriver = toString a.cc;
            runtimeDirectories = a.base.runtimeDirectories; }}''')
    return result


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
