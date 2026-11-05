"""Opt-in GNU graph audit; existing musl audit entrypoint remains unchanged."""
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent


def run():
    endpoints = ['gnu-cross', 'gnu-core-bridge', 'gnu-libc', 'gnu-libgcc',
                 'gnu-libstdcxx', 'gnu-bash', 'gnu-binutils', 'gnu-gmp',
                 'gnu-mpfr', 'gnu-mpc', 'gnu-libiberty', 'gnu-libbacktrace',
                 'gnu-gcc-unwrapped', 'gnu-gcc', 'gnu-tests',
                 'tests.consumer', 'tests.versions', 'tests.cxx', 'tests.tools',
                 'tests.transitions', 'tests.libc', 'tests.stage-comparison',
                 'tests.gcc10', 'tests.gcc10-archives', 'tests.gcc16', 'tests.prerequisites']
    raw = audit.nix_json('derivation', 'show', '--recursive', '--file', str(ROOT), *endpoints)
    sources = audit.nix_json('eval', '--json', '--impure', '--expr',
                            f'let b = import {ROOT} {{}}; in builtins.mapAttrs (_: p: toString p) b.sources')
    provenance = json.loads((ROOT / 'provenance.json').read_text())
    provenance['archives'] += json.loads((ROOT / 'gnu-sources.json').read_text())['archives']
    early = audit.nix_json('derivation', 'show', '--recursive', '--file', str(ROOT), 'compiler', 'libc')
    early_outputs = [audit.store_path(output.get('path', node['env'][name]))
                     for node in early.get('derivations', early).values()
                     for name, output in node['outputs'].items()]
    return audit.audit_graph(raw, sources, provenance,
                             json.loads((ROOT / 'stage0-sources.json').read_text()), early_outputs)


if __name__ == '__main__':
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
