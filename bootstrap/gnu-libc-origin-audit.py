"""Add the libc capability graph without changing prior origin/runner profiles."""
import importlib
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent


def run():
    prior = importlib.import_module('gnu-environment-audit').run()
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file', str(ROOT / 'gnu-libc-profile-tests.nix'))
    sources = audit.nix_json('eval', '--json', '--impure', '--expr',
                            f'let b=import {ROOT} {{}}; in builtins.mapAttrs (_: p: toString p) b.sources')
    provenance = json.loads((ROOT / 'provenance.json').read_text())
    provenance['archives'] += json.loads((ROOT / 'gnu-sources.json').read_text())['archives']
    result = audit.audit_graph(raw, sources, provenance,
        json.loads((ROOT / 'stage0-sources.json').read_text()), prior['runtimeForbiddenExecutableRoots'])
    for key in ['nodes', 'sourceData']:
        for name in prior[key].keys() & result[key].keys():
            if prior[key][name] != result[key][name]:
                result['failures'].append('Changed previous origin: ' + name)
        result[key] = prior[key] | result[key]
    result['ownedRunnerProfile'] = prior['ownedRunnerProfile']
    result['failures'] += prior['failures']
    return result


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
