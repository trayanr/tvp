"""Strict output generation assignments for the new installed tools and arithmetic project."""
import importlib
import hashlib
import tarfile
import json
from pathlib import Path
import sys
import audit

ROOT = Path(__file__).resolve().parent


def ninja_data(root, archive):
    root = Path(root)
    expected = {
        'share/ninja/ninja_syntax.py': 'misc/ninja_syntax.py',
        'share/doc/ninja/manual.asciidoc': 'doc/manual.asciidoc',
        'share/licenses/ninja/COPYING': 'COPYING',
    }
    files = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}
    if files != set(expected) | {'bin/ninja'}:
        raise ValueError('Unexpected installed Ninja files')
    result = {}
    with tarfile.open(archive, 'r:gz') as source:
        for relative, member in expected.items():
            path = root / relative
            raw = source.extractfile('ninja-1.13.2/' + member).read()
            if relative.endswith('.py'):
                raw = raw.split(b'\n', 1)[1]
            if path.is_symlink() or path.stat().st_mode & 0o111 or path.read_bytes() != raw:
                raise ValueError('Executable or modified Ninja source data: ' + relative)
            result[relative] = dict(role='nonexecutable-source-data',
                                    sha256=hashlib.sha256(raw).hexdigest(), archiveMember=member)
    return result


def run(origin):
    # Retain the independent old runtime result; do not authorize either loader
    # across generations or infer permissions from the union construction graph.
    prior = importlib.import_module('source-consumer-runtime-audit').run(origin)
    if prior['failures']:
        raise ValueError('Prior runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let b=import {ROOT} {{}}; p=import {ROOT}/gnu-target-profile.nix {{}};
          f=import {ROOT}/source-build-tool-tests.nix {{}};
      in {{ new=map toString [p.libc p.libgcc p.libstdcxx f.chain.gmp f.chain.mpfr f.chain.mpc f.tools.pkgConfig f.tools.ninja f.consumer];
            old=map toString [b.gnu-libc b.gnu-libgcc b.gnu-bash];
            data=[(toString b.linux-headers)];
            newSearch=["${{p.libc}}/lib" "${{p.libgcc}}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"
                       "${{p.libstdcxx}}/lib" "${{f.chain.gmp}}/lib" "${{f.chain.mpfr}}/lib" "${{f.chain.mpc}}/lib"];
            oldSearch=["${{b.gnu-libc}}/lib" "${{b.gnu-libgcc}}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"];
            ninja=toString f.tools.ninja; ninjaArchive=toString f.tools.sources.ninja;
            readelf="${{b.gnu-binutils}}/bin/readelf"; }}''')
    profile = dict(roots=m['new'], readelf=m['readelf'], data=m['data'], generations={
        'source-build-tool-target': dict(executables=m['new'], loader=m['new'][0] + '/lib/ld-linux-x86-64.so.2', search=m['newSearch']),
        'prior-shell-runtime': dict(executables=m['old'], loader=m['old'][0] + '/lib/ld-linux-x86-64.so.2', search=m['oldSearch'])})
    result = importlib.import_module('gnu-libc-runtime-audit').audit(origin, profile)
    result['ninjaData'] = ninja_data(m['ninja'], m['ninjaArchive'])
    result['priorRuntime'] = dict(files=len(prior['files']), failures=prior['failures'])
    return result


if __name__ == '__main__':
    result = run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
