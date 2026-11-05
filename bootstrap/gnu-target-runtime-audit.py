"""Bind exact output generations to the existing strict staged runtime auditor."""
import importlib
import json
from pathlib import Path
import subprocess
import sys
import audit

ROOT = Path(__file__).resolve().parent


def run(origin):
    metadata = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let b=import {ROOT} {{}}; p=import {ROOT}/gnu-target-profile.nix {{}};
          f=import {ROOT}/gnu-target-tests.nix {{}};
      in {{ new=map toString [p.libc p.libgcc p.libstdcxx f.probe f.installed
                             f.a f.a11 f.libraryB f.libraryB11 f.consumer f.override f.edited f.customized f.protocol];
            old=map toString [b.gnu-libc b.gnu-libgcc b.gnu-bash];
            data=[(toString b.linux-headers)];
            newSearch=["${{p.libc}}/lib" "${{p.libgcc}}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0" "${{p.libstdcxx}}/lib"];
            oldSearch=["${{b.gnu-libc}}/lib" "${{b.gnu-libgcc}}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"];
            readelf="${{b.gnu-binutils}}/bin/readelf";
      }}''')
    profile = dict(roots=metadata['new'], readelf=metadata['readelf'], data=metadata['data'],
        generations={
            'capability-target': dict(executables=metadata['new'],
                loader=metadata['new'][0] + '/lib/ld-linux-x86-64.so.2', search=metadata['newSearch']),
            'prior-shell-runtime': dict(executables=metadata['old'],
                loader=metadata['old'][0] + '/lib/ld-linux-x86-64.so.2', search=metadata['oldSearch'])})
    # New fixture DSOs are authoritative providers alongside the base runtime.
    profile['generations']['capability-target']['search'] += [p + '/lib' for p in metadata['new'][5:9]]
    return importlib.import_module('gnu-libc-runtime-audit').audit(origin, profile)


if __name__ == '__main__':
    result = run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
