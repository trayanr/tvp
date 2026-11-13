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
    prior = importlib.import_module('gnu-target-origin-audit').run()
    if prior['failures']:
        raise ValueError('Prior construction audit failed')
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file',
                         str(ROOT / 'source-consumer-tests.nix'), 'consumer',
                         'chain.evidence.gmp', 'chain.evidence.mpfr', 'chain.evidence.mpc',
                         'chain.mpfr.tests.upstream')
    graph = raw.get('derivations', raw)
    normalized = copy.deepcopy(graph)
    roles = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let f=import {ROOT}/source-consumers.nix {{}}; b=import {ROOT} {{}};
      in {{ shell="${{f.composition.bash}}/bin/bash";
            coreutils=toString f.composition.coreutils;
            build=map toString [b.gnu-gcc-unwrapped b.gnu-binutils b.build-python b.build-m4
              b.gnu-tool-floor.gnu-make b.gnu-tool-floor.gnu-findutils];
            target=map toString [f.composition.cc.libc f.gmp f.mpfr f.mpc];
            mpfr={{ artifact=f.mpfr.artifact.drvPath; final=f.mpfr.drvPath;
                    upstream=f.mpfr.tests.upstream.drvPath;
                    raw=f.mpfr.tests.upstream.specification.validation.execution.drvPath;
                    production=f.mpfr.tests.upstream.specification.validation.production.drvPath; }};
          }}''')
    producers = {audit.store_path(o.get('path', n['env'][name])): audit.store_path(d)
                 for d, n in graph.items() for name, o in n['outputs'].items()}
    profiles, failures = {}, []
    mpfr = {role: audit.store_path(drv) for role, drv in roles['mpfr'].items()}
    mpfr_roles = {mpfr[role]: role for role in ('artifact', 'final', 'upstream', 'raw')}
    if mpfr['production'] != mpfr['artifact']:
        failures.append('MPFR upstream production is not its compilation artifact')
    if len(mpfr_roles) != 4:
        failures.append('MPFR artifact, final and upstream roles are not distinct')
    graph_drvs = {audit.store_path(drv) for drv in graph}
    failures += ['Missing MPFR ' + role + ' runner: ' + drv
                 for drv, role in mpfr_roles.items() if drv not in graph_drvs]
    stage_names = {'gmp-6.3.0', 'mpc-1.4.1',
                   'gmp-6.3.0-artifacts', 'mpc-1.4.1-artifacts',
                   'source-gmp-evidence-6.3.0', 'source-mpfr-evidence-4.2.2',
                   'source-mpc-evidence-1.4.1', 'source-arithmetic-consumers-1'}
    for drv, n in normalized.items():
        full = audit.store_path(drv)
        mpfr_role = mpfr_roles.get(full)
        if mpfr_role is not None and 'structuredAttrs' not in n:
            failures.append('Invalid MPFR ' + mpfr_role + ' runner: ' + full)
            continue
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
            if name in {'gmp-6.3.0', 'mpc-1.4.1'} or mpfr_role == 'final':
                expected_fields.add('outputChecks')
                refs = data.get('outputChecks', {}).get('out', {}).get('disallowedReferences', [])
                checks_valid = (len(refs) == 1 and producers.get(refs[0]) in deps
                                and refs[0].endswith(name + '-artifacts')
                                and data['outputChecks'] == {'out': {'disallowedReferences': refs}})
                if mpfr_role == 'final':
                    checks_valid = checks_valid and producers.get(refs[0]) == mpfr['artifact']
            valid = (checks_valid and (name in stage_names or mpfr_role is not None)
                     and n['builder'] == roles['shell']
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
            failures.append('Invalid source consumer runner: ' + full)
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
            if p in prior['sourceData'] and Path(p).is_dir():
                srcs.remove(src)
    pins = copy.deepcopy(prior['constructionPins'])
    pins['archives'] += list(json.loads((ROOT / 'source-consumer-sources.json').read_text()).values())
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
