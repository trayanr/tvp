"""Strict output generation assignments for the new installed arithmetic chain."""
import importlib
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent


def run(origin):
    # Retain the independent old runtime result; do not authorize either loader
    # across generations or infer permissions from the union construction graph.
    prior = importlib.import_module('gnu-target-runtime-audit').run(origin)
    if prior['failures']:
        raise ValueError('Prior runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let b=import {ROOT} {{}}; p=import {ROOT}/gnu-target-profile.nix {{}};
          f=import {ROOT}/source-consumer-tests.nix {{}};
      in {{ new=map toString [p.libc p.libgcc p.libstdcxx f.chain.gmp f.chain.mpfr f.chain.mpc f.consumer];
            old=map toString [b.gnu-libc b.gnu-libgcc b.gnu-bash];
            data=[(toString b.linux-headers)];
            newSearch=["${{p.libc}}/lib" "${{p.libgcc}}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"
                       "${{p.libstdcxx}}/lib" "${{f.chain.gmp}}/lib" "${{f.chain.mpfr}}/lib" "${{f.chain.mpc}}/lib"];
            oldSearch=["${{b.gnu-libc}}/lib" "${{b.gnu-libgcc}}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"];
            readelf="${{b.gnu-binutils}}/bin/readelf"; }}''')
    profile = dict(roots=m['new'], readelf=m['readelf'], data=m['data'], generations={
        'source-consumer-target': dict(executables=m['new'], loader=m['new'][0] + '/lib/ld-linux-x86-64.so.2', search=m['newSearch']),
        'prior-shell-runtime': dict(executables=m['old'], loader=m['old'][0] + '/lib/ld-linux-x86-64.so.2', search=m['oldSearch'])})
    result = importlib.import_module('gnu-libc-runtime-audit').audit(origin, profile)
    result['priorRuntime'] = dict(files=len(prior['files']), failures=prior['failures'])
    return result


if __name__ == '__main__':
    result = run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
