"""Bounded native ELF observer, separate from Perl's development reference closure.

Compiler references in Config/ExtUtils remain development capabilities. They do
not grant compiler executables membership in the interpreter's native generation.
"""
import importlib
import json
from pathlib import Path
import re
import subprocess
import sys
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
generation = importlib.import_module('gnu-libc-runtime-audit')


def scan(roots, permitted, loader, readelf):
    failures, files = [], {}
    for root in roots:
        for file in sorted(Path(root).rglob('*')):
            if not file.is_file():
                continue
            if file.is_symlink():
                with file.open('rb') as stream:
                    if stream.read(4) == b'\x7fELF' and not strict.owned_executable(str(file), permitted):
                        failures.append('Escaping native ELF symlink: '+str(file))
                continue
            with file.open('rb') as stream:
                if stream.read(4) != b'\x7fELF':
                    continue
            info = subprocess.check_output([readelf, '-h', '-l', '-d', str(file)], text=True)
            interp = re.findall(r'Requesting program interpreter: ([^\]]+)', info)
            needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', info)
            raw = re.findall(r'\((?:RPATH|RUNPATH)\).*\[([^\]]*)\]', info)
            search = [generation.expand_search(s, file) for group in raw for s in group.split(':')]
            if 'Advanced Micro Devices X86-64' not in info:
                failures.append('Foreign machine: '+str(file))
            if any(i != loader for i in interp):
                failures.append('Foreign interpreter: '+str(file))
            if any(not s or not strict.within(s, permitted) for s in search):
                failures.append('Foreign search: '+str(file))
            resolved = {n: strict.resolve_needed(n, [s for s in search if s], permitted, permitted) for n in needed}
            if None in resolved.values():
                failures.append('Unresolved dependency: '+str(file))
            listing = None
            if interp or needed:
                p = subprocess.run([loader, '--list', str(file)], env={}, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                listing = p.stdout
                actual = re.findall(r'^\s*(\S+) => (/.*?) \(0x[0-9a-f]+\)$', listing, re.M)
                actual = {n: str(Path(p).resolve()) for n,p in actual}
                direct = re.findall(r'^\s*(/.*?) \(0x[0-9a-f]+\)$', listing, re.M)
                for path in direct:
                    if path != loader:
                        failures.append('Foreign loader entry: '+path)
                    actual[Path(path).name] = str(Path(path).resolve())
                if p.returncode or any(not strict.owned_executable(p, permitted) for p in actual.values()):
                    failures.append('Actual foreign loader dependency: '+str(file))
                if any(actual.get(n) != path for n,path in resolved.items()):
                    failures.append('Loader resolution mismatch: '+str(file))
            files[str(file)] = dict(interpreter=interp, needed=resolved, soname=re.findall(r'\(SONAME\).*\[([^\]]+)\]', info), search=search, actualLoaderListing=listing)
    return files, failures


def run(origin):
    # Existing strict runtime observers remain independently required and unchanged.
    prior = importlib.import_module('source-build-tool-runtime-audit').run(origin)
    if prior['failures']:
        raise ValueError('Prior runtime failed')
    m = audit.nix_json('eval','--impure','--json','--expr',f'''
      let t=import {ROOT}/source-cmake-prerequisite-tests.nix {{}};
          p=import {ROOT}/gnu-target-profile.nix {{}}; b=import {ROOT} {{}};
      in {{ packages=builtins.mapAttrs (_: x: toString x) {{inherit (t.f) perl openssl zlib bzip2 xz zstd;}};
            consumer=toString t.consumer; evidence=toString t.consumer.evidence;
            native=map toString [p.libc p.libgcc p.libstdcxx];
            helper=map toString [b.gnu-bash b.gnu-libc b.gnu-libgcc];
            nativeData=[(toString b.linux-headers)];
            priorShell=toString b.gnu-bash;
            loader="${{p.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{b.gnu-binutils}}/bin/readelf"; }}''')
    permitted = set(m['native'] + list(m['packages'].values()) + [m['consumer']])
    assert permitted <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    files, failures = scan(list(m['packages'].values())+[m['consumer']],permitted,m['loader'],m['readelf'])
    full = audit.nix_json('path-info','--json','--recursive',m['packages']['perl'])
    closure = sorted(full if isinstance(full,dict) else (x['path'] for x in full))
    known = strict.origin_paths(origin)
    if any(p not in known for p in closure):
        failures.append('Unclassified Perl reference closure')
    development = sorted(set(closure)-permitted)
    reference_roles = {p: dict(origin=known[p], role=('selected-native-generation' if p in permitted else 'development/build-reference; no native executable permission')) for p in closure}
    config = {}
    for pattern in ['Config.pm','Config_heavy.pl']:
        for path in Path(m['packages']['perl']).rglob(pattern):
            config[str(path)] = sorted(set(re.findall(r'/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+',path.read_text())))
    scripts = {}
    # Runtime entrypoints only. Perl library source may contain documentation or
    # example shebangs; neither those nor Config strings authorize interpreters.
    script_roots = {m['packages']['perl'], m['priorShell']}
    for package in m['packages'].values():
        for path in (Path(package)/'bin').glob('*'):
            if not path.is_file() or path.is_symlink():
                continue
            with path.open('rb') as stream:
                head = stream.read(512)
            if head.startswith(b'#!'):
                words=head.split(b'\n',1)[0][2:].decode().split()
                interpreter=words[0] if words else ''
                if not strict.owned_executable(interpreter,script_roots):
                    failures.append('Foreign installed script interpreter: '+str(path))
                scripts[str(path)]=interpreter
    maps = {}
    for path in Path(m['evidence']).glob('*.log'):
        if path.name.endswith('-installed.log') or path.name in ['perl-native.log','xs-import.log','xs-installed-import.log']:
            paths = sorted(set(re.findall(r'/nix/store/[^\s]+',path.read_text())))
            if any(not strict.owned_executable(p,permitted) for p in paths):
                failures.append('Foreign actual process map: '+str(path))
            maps[path.name] = paths
    zstd_features = subprocess.check_output([m['packages']['zstd']+'/bin/zstd','-vvV'],env={},text=True,stderr=subprocess.STDOUT)
    if any(s not in zstd_features for s in ['gzip, lzma, xz', 'zlib version 1.3.2', 'lzma version 5.8.4', 'lz4 version Unsupported']):
        failures.append('Unexpected installed Zstd codec features')
    interfaces = {}
    for name, header, library, soname in [
            ('zlib','zlib.h','z','libz.so.1'),
            ('bzip2','bzlib.h','bz2','libbz2.so.1.0'),
            ('xz','lzma.h','lzma','liblzma.so.5'),
            ('zstd','zstd.h','zstd','libzstd.so.1'),
            ('openssl','openssl/ssl.h','ssl','libssl.so.4')]:
        root=Path(m['packages'][name])
        shared=root/'lib'/('lib'+library+'.so')
        static=root/'lib'/('lib'+library+'.a')
        if not (root/'include'/header).is_file() or not static.is_file() or not shared.is_file():
            failures.append('Missing public header/shared/static interface: '+name)
        elif files[str(shared.resolve())]['soname'] != [soname]:
            failures.append('Wrong public SONAME: '+name)
        interfaces[name]=dict(header=str(root/'include'/header), static=str(static),
            shared=str(shared), soname=soname,
            symlinks={str(p):str(p.resolve()) for p in (root/'lib').glob('*.so*') if p.is_symlink()},
            pkgconfig={p.name:p.read_text() for p in (root/'lib/pkgconfig').glob('*.pc')})
    nonperl = audit.nix_json('path-info','--json','--recursive',*[v for k,v in m['packages'].items() if k!='perl'])
    nonperl = set(nonperl if isinstance(nonperl,dict) else (x['path'] for x in nonperl))
    # Their helper scripts legitimately retain the old GNU shell generation.
    allowed_helper = set(m['helper'] + m['nativeData'])
    native_without_perl = permitted - {m['packages']['perl'], m['consumer']}
    if nonperl - native_without_perl - allowed_helper:
        failures.append('Unexpected codec/OpenSSL runtime reference')
    return dict(schema=1, failures=failures, files=files, zstdFeatures=zstd_features, publicInterfaces=interfaces, installedScripts=scripts, permittedNative=sorted(permitted),
                actualProcessMaps=maps, perlFullReferenceClosure=closure,
                perlDevelopmentAndBuildReferences=development, perlReferenceRoles=reference_roles, perlConfigReferences=config,
                nonPerlReferenceClosure=sorted(nonperl), priorRuntimeFiles=len(prior['files']),
                limits='All new installed ELF and actual consumer maps; compiler closure is development/build capability, never native runtime permission.')


if __name__ == '__main__':
    result=run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result,indent=2,sort_keys=True))
    sys.exit(bool(result['failures']))
