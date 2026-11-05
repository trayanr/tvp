"""Opt-in owned output-tool ledger; prior strict profiles remain unchanged."""
import copy
import hashlib
import importlib
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent


def run():
    prior = importlib.import_module('gnu-libc-origin-audit').run()
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file',
                         str(ROOT / 'output-tool-prerequisites.nix'),
                         'patchelf', 'mpfr', 'consumer')
    contracts = audit.nix_json('derivation', 'show', '--recursive', '--file',
                               str(ROOT / 'output-tool-contracts.nix'), 'unpack')
    graph = raw.get('derivations', raw) | contracts.get('derivations', contracts)
    normalized = copy.deepcopy(graph)
    b = audit.nix_json('eval', '--json', '--impure', '--expr',
                       f'let b=import {ROOT} {{}}; in {{bash=toString b.gnu-bash; coreutils=toString b.gnu-tool-floor.gnu-coreutils;}}')
    shell, cp = b['bash'] + '/bin/bash', b['coreutils'] + '/bin/cp'
    producers = {audit.store_path(o.get('path', n['env'][name])): audit.store_path(d)
                 for d, n in graph.items() for name, o in n['outputs'].items()}
    profiles, failures = {}, []
    helper_trees = {}
    expected_trees = {
        'native-output': {'check-paths.py', 'check-symlinks.py', 'common.py',
                          'development.py', 'libtool.py', 'rpaths.py', 'strip.py'},
        'output-tools': {'shared.py', 'shebangs.py', 'strip-archives.py'},
    }
    for directory, expected in expected_trees.items():
        tree = audit.nix_json('eval', '--json', '--impure', '--expr',
                              f'"${{{ROOT.parent}/lib/{directory}}}"')
        hashes = {}
        for p in Path(tree).rglob('*'):
            if not p.is_file() or p.is_symlink() or p.suffix != '.py':
                raise ValueError('Unexpected owned output helper entry: ' + str(p))
            data = p.read_bytes()
            if data.startswith((b'\x7fELF', b'MZ')):
                raise ValueError('Executable data in helper tree')
            hashes[p.name] = hashlib.sha256(data).hexdigest()
        if set(hashes) != expected:
            raise ValueError('Unexpected owned helper tree: ' + tree)
        helper_trees[tree] = dict(origin='owned-source-or-nix-generated-text',
                                  filesSHA256=hashes)
    names = {'tvp-standalone-patchelf-0.19.2', 'mpfr-4.2.2-artifacts',
             'mpfr-4.2.2', 'tvp-standalone-mpfr-consumer-1',
             'tvp-output-tool-unpack-contracts-1'}
    for drv, node in normalized.items():
        full = audit.store_path(drv)
        if full in prior['nodes']:
            continue
        name = node.get('name', node['env'].get('name', ''))
        deps = {audit.store_path(p) for p in node.get('inputs', {}).get('drvs', {})}
        if name in names and 'structuredAttrs' in node:
            data = node['structuredAttrs']
            valid = (node['builder'] == shell and node['args'][0] == '-euc'
                     and node['args'][1].startswith('source "$NIX_ATTRS_SH_FILE"\n')
                     and set(data) == ({'builder', 'name', 'outputs', 'stageInputs', 'system'}
                                         | ({'outputChecks'} if name == 'mpfr-4.2.2' else set()))
                     and (name != 'mpfr-4.2.2' or (
                         set(data['outputChecks']) == {'out'}
                         and set(data['outputChecks']['out']) == {'disallowedReferences'}
                         and len(data['outputChecks']['out']['disallowedReferences']) == 1
                         and producers.get(data['outputChecks']['out']['disallowedReferences'][0]) in deps))
                     and all(producers.get(p) in deps for p in data['stageInputs']))
            if not valid:
                failures.append('invalid selected owned stage: ' + full)
                continue
            kind = 'owned-structured-stage'
        elif name == 'tvp-build-step-runner' or name.startswith('tvp-step-'):
            env = node['env']
            if not (node['builder'] == shell and node['args'] == ['-euc', cp + ' "$textPath" "$out"']
                    and env.get('passAsFile') == 'text' and env.get('allowSubstitutes') == '1'
                    and 'text' in env and 'PATH' not in env
                    and producers.get(b['coreutils']) in deps):
                failures.append('invalid owned script: ' + full)
                continue
            kind = 'owned-text-copy'
        else:
            continue
        profiles[full] = dict(kind=kind, actualEnvironment=graph[drv]['env'],
                              actualStructuredAttrs=graph[drv].get('structuredAttrs'),
                              commandSHA256=hashlib.sha256(json.dumps(node['args']).encode()).hexdigest(),
                              substitutionPolicy='Nix default; retained logs prove local execution')
        node['env']['PATH'] = ''
        node['env']['allowSubstitutes'] = ''
    # Historical structured runner forms are classified only by the unchanged
    # prior auditor. They are not reauthorized by this new profile.
    # Keep dependencies present for exact executable-edge resolution.
    for d, n in normalized.items():
        if audit.store_path(d) in prior['nodes']:
            if audit.store_path(d) in prior['ownedRunnerProfile']:
                n['env']['PATH'] = ''
                n['env']['allowSubstitutes'] = ''
    sources = audit.nix_json('eval', '--json', '--impure', '--expr',
                            f'let b=import {ROOT} {{}}; in builtins.mapAttrs (_: p: toString p) b.sources')
    provenance = copy.deepcopy(prior['constructionPins'])
    # The prior libc auditor's provenance omits the tool-floor pins; merge by URL.
    pins = provenance['archives'] + list(json.loads((ROOT / 'gnu-tool-floor-sources.json').read_text())['archives'].values())
    pins += list(json.loads((ROOT / 'output-tool-sources.json').read_text()).values())
    provenance['archives'] = list({p['url']: p for p in pins}.values())
    # Only these exact checked Python source trees are removed from the old
    # single-file data profile. It never authorizes a native executable.
    for n in normalized.values():
        srcs = n.get('inputs', {}).get('srcs', [])
        for tree in helper_trees:
            if tree.removeprefix('/nix/store/') in srcs:
                srcs.remove(tree.removeprefix('/nix/store/'))
    result = audit.audit_graph(normalized, sources, provenance,
                               prior['stage0Pins'], prior['runtimeForbiddenExecutableRoots'])
    # Exactly preserve each prior node's audited representation.
    result['nodes'] = prior['nodes'] | {k: v for k, v in result['nodes'].items() if k not in prior['nodes']}
    result['sourceData'] = prior['sourceData'] | result['sourceData'] | helper_trees
    result['ownedRunnerProfile'] = prior['ownedRunnerProfile'] | profiles
    result['failures'] += failures + prior['failures']
    result['buildToolRoles'] = audit.nix_json('eval', '--json', '--file', str(ROOT / 'output-tool-prerequisites.nix'), 'metadata')
    return result


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
