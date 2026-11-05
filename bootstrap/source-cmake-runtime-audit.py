"""CMake native execution and developer/module reference roles are separate."""
import importlib
import hashlib
import tarfile
import json
from pathlib import Path
import re
import subprocess
import sys
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
boundary = importlib.import_module('source-cmake-prerequisite-runtime-audit')


SHELL_MODULES = {
    'Modules/Compiler/XL-Fortran/cpp',
    'Modules/Internal/CPack/CPack.RuntimeScript.in',
    'Modules/Internal/CPack/CPack.STGZ_Header.sh.in',
    'Modules/Platform/AIX/ExportImportList',
    'Modules/Squish4RunTestCase.sh',
    'Modules/SquishRunTestCase.sh',
}


def module_data(root, archive, shell):
    root = Path(root)
    with tarfile.open(archive, 'r|gz') as source:
        members = {m.name.removeprefix('cmake-4.4.5/'): source.extractfile(m).read()
                   for m in source if m.isfile() and any(x in m.name for x in ['/Modules/', '/Templates/', '/Help/'])}
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('Symlink in installed module data: ' + str(path))
        if not path.is_file(): continue
        relative = str(path.relative_to(root))
        original = members.get(relative)
        if original is None:
            raise ValueError('Module absent from pinned archive: ' + relative)
        expected = original
        if relative in SHELL_MODULES:
            assert original.split(b'\n', 1)[0] in [b'#!/bin/sh', b'#!/usr/bin/env bash']
            expected = b'#!' + shell.encode() + b'\n' + original.split(b'\n', 1)[1]
        if path.read_bytes() != expected:
            raise ValueError('Unexpected installed module content: ' + relative)
        role = ('owned-shell-template' if relative.endswith('.in') else 'owned-shell-helper') if relative in SHELL_MODULES else ('GHS project template/header; no interpreter permission' if relative.startswith('Modules/CompilerId/GHS') else 'CMake-interpreted source/data')
        result[relative] = dict(role=role, executable=bool(path.stat().st_mode & 0o111),
            sourceMember='cmake-4.4.5/' + relative,
            sourceSHA256=hashlib.sha256(original).hexdigest(), installedSHA256=hashlib.sha256(expected).hexdigest())
    if not result: raise ValueError('Empty module tree')
    return result


def run(origin):
    prior = boundary.run(origin)
    if prior['failures']:
        raise ValueError('Prior runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let t=import {ROOT}/source-cmake-tests.nix {{}}; b=import {ROOT} {{}};
          p=import {ROOT}/gnu-target-profile.nix {{}};
      in {{ packages=builtins.mapAttrs (_: x: toString x) {{inherit (t.f) cmake jsonC; consumer=t.consumer; runtimeJson=t.runtimeJson;}};
            libraries=map toString [t.f.prerequisites.openssl t.f.prerequisites.zlib
              t.f.prerequisites.bzip2 t.f.prerequisites.xz t.f.prerequisites.zstd];
            native=map toString [p.libc p.libgcc p.libstdcxx];
            helper=map toString [b.gnu-bash b.gnu-libc b.gnu-libgcc];
            evidence=toString t.consumer.evidence;
            cmakeEvidence=toString t.f.cmake.evidence;
            jsonArtifact=toString t.f.jsonC.artifact;
            compiler=toString t.f.composition.cc;
            moduleArchive=toString t.f.sources.cmake;
            shell="${{t.f.composition.bash}}/bin/bash";
            sourceData=[(toString b.linux-headers) "${{{ROOT}/../pkgs/libraries/json-c/tests/fixtures/api.c}}"];
            loader="${{p.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{b.gnu-binutils}}/bin/readelf"; }}''')
    permitted = set(m['native'] + m['libraries'] + list(m['packages'].values()))
    assert permitted <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    files, failures = boundary.scan(m['packages'].values(), permitted, m['loader'], m['readelf'])
    cmake = Path(m['packages']['cmake'])
    # All four codecs and TLS must be actual linked providers, not cache flags.
    for exe in ['cmake', 'ctest', 'cpack']:
        info = files[str(cmake / 'bin' / exe)]
        required = ['libssl.so.4', 'libcrypto.so.4', 'libz.so.1', 'libbz2.so.1.0', 'liblzma.so.5', 'libzstd.so.1']
        for lib in required:
            if not info['needed'].get(lib):
                failures.append('Missing selected provider: ' + exe + ': ' + lib)
    known = strict.origin_paths(origin)
    raw = audit.nix_json('path-info', '--json', '--recursive', *m['packages'].values())
    closure = sorted(raw if isinstance(raw, dict) else (p['path'] for p in raw))
    if set(closure) - set(known):
        failures.append('Unclassified full reference closure')
    data = module_data(cmake / 'share/cmake-4.4', m['moduleArchive'], m['shell'])
    references, scripts = {}, {}
    if set(closure) - permitted - set(m['helper']) - set(m['sourceData']):
        failures.append('Unexpected full reference role')
    for path in sorted(cmake.rglob('*')):
        if not path.is_file(): continue
        relative = str(path.relative_to(cmake))
        with path.open('rb') as stream: head = stream.read(4)
        if head == b'\x7fELF': continue
        raw = path.read_bytes()
        refs = sorted(set(re.findall(rb'/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+', raw)))
        if refs: references[relative] = [r.decode() for r in refs]
        if raw.startswith(b'#!'):
            # Modules contain example and auxiliary scripts, including other-platform
            # templates. Keep exact text and role; they are not cmake ELF loaders.
            scripts[relative] = dict(shebang=raw.split(b'\n', 1)[0].decode(),
                role=data[relative.removeprefix('share/cmake-4.4/')]['role'] if relative.startswith('share/') else 'installed entrypoint')
    if not (cmake / 'share/cmake-4.4/Modules/FindZLIB.cmake').is_file():
        failures.append('Missing installed modules')
    if not data: failures.append('No installed module data')
    maps = {}
    for path in Path(m['evidence']).glob('*-loader.log'):
        text = path.read_text()
        paths = sorted(set(re.findall(r'calling init: (/\S+)', text)))
        if not paths or any(not strict.owned_executable(p, permitted) for p in paths):
            failures.append('Foreign or empty actual process map: ' + path.name)
        maps[path.name] = paths
    if len(maps) != 2: failures.append('Missing installed process maps')
    check = Path(m['jsonArtifact']) / '.tvp-evidence/json-c.check.log'
    measured = re.findall(r'100% tests passed out of (\d+)', check.read_text())
    if measured != ['28']:
        failures.append('Missing JSON-C 28-case result')
    cache = (Path(m['cmakeEvidence']) / 'CMakeCache.txt').read_text()
    if 'BUILD_TESTING:BOOL=OFF' not in cache: failures.append('Production testing policy changed')
    return dict(schema=1, failures=failures, files=files, permittedNative=sorted(permitted),
        priorRuntimeFiles=len(prior['files']), fullReferenceClosure=closure,
        referenceRoles={p: dict(origin=known.get(p), role='selected-native-generation' if p in permitted else ('prior-owned-shell-generation; separate native permission' if p in m['helper'] else 'source/header-data; no native executable permission')) for p in closure},
        installedModuleData=data, installedTextReferences=references, moduleScripts=scripts,
        actualProcessMaps=maps, jsonCUpstreamCases=int(measured[0]) if measured else 0,
        limits='Bounded CMake upstream subset; compiler/development/module references retained separately. No full conformance or selfhosting claim.')


if __name__ == '__main__':
    result = run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
