"""Native execution is bounded independently from Python's full development closure."""
import hashlib
import importlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import zipfile
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
boundary = importlib.import_module('source-cmake-prerequisite-runtime-audit')


def zip_data(zipapp, archive, python):
    with tarfile.open(archive) as source:
        original = {m.name.removeprefix('meson-1.12.1/'): source.extractfile(m).read()
                    for m in source if m.isfile()}
    data = {}
    raw = Path(zipapp).read_bytes()
    assert raw.split(b'\n', 1)[0] == ('#!' + python + '/bin/python3').encode()
    with zipfile.ZipFile(zipapp) as z:
        for member in z.infolist():
            if member.is_dir(): continue
            assert member.compress_type == zipfile.ZIP_DEFLATED
            content = z.read(member)
            if member.filename == '__main__.py':
                assert content == original['meson.py']
                role = 'pinned-zipapp-bootstrap'
            else:
                expected = original.get(member.filename)
                assert expected is not None, member.filename
                if member.filename == 'mesonbuild/scripts/depfixer.py':
                    expected = expected.replace(b"            for rpath_dir in old_rpath.split(b':'):\n",
                        b"            for rpath_dir in old_rpath.split(b':'):\n"
                        b"                if rpath_dir.startswith(b'/nix/store/'):\n"
                        b"                    new_rpaths.add(rpath_dir)\n"
                        b"                    continue\n")
                assert content == expected, member.filename
                role = 'pinned-module-data; no native executable permission'
            data[member.filename] = dict(sha256=hashlib.sha256(content).hexdigest(), role=role)
    assert len(data) > 100
    return data


def python_data(root, archive, shell):
    root=Path(root)
    with tarfile.open(archive) as source:
        original={m.name.removeprefix('Python-3.12.5/Lib/'):source.extractfile(m).read()
                  for m in source if m.isfile() and m.name.startswith('Python-3.12.5/Lib/')}
    result={}
    for path in (root/'lib/python3.12').rglob('*.py'):
        relative=str(path.relative_to(root/'lib/python3.12'))
        content=path.read_bytes()
        if relative in ['_sysconfigdata__linux_x86_64-linux-gnu.py', 'config-3.12-x86_64-linux-gnu/python-config.py']:
            role='generated installed development metadata; retained compiler capability'
        else:
            expected=original.get(relative)
            assert expected is not None,relative
            if relative=='subprocess.py':
                expected=expected.replace(b"else '/bin/sh')",("else '"+shell+"')").encode())
            if expected.startswith(b'#!'):
                expected=b'#!'+str(root).encode()+b'/bin/python3\n'+expected.split(b'\n',1)[1]
            assert expected==content,relative
            role='pinned stdlib data with declared subprocess/shell binding; no native ELF permission'
        result[relative]=dict(sha256=hashlib.sha256(content).hexdigest(),role=role)
    assert len(result)>500
    for name in ['install-sh','makesetup']:
        paths=list((root/'lib/python3.12').glob('config-*/'+name));assert len(paths)==1
        assert paths[0].read_bytes().startswith(('#!'+shell+'\n').encode())
    return result


def run(origin):
    prior = importlib.import_module('source-cmake-runtime-audit').run(origin)
    assert not prior['failures']
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let t=import {ROOT}/source-python-meson-tests.nix {{}}; f=t.f;
          p=import {ROOT}/gnu-target-profile.nix {{}}; b=import {ROOT} {{}};
      in {{ packages=builtins.mapAttrs (_: x: toString x) {{inherit (f) python meson;
              pythonOpenssl=f.pythonOpenssl; pythonConsumer=t.python; mesonConsumer=t.meson; helperConsumer=t.helperConsumer;
              selectedMeson=t.selectedMeson; traced=t.traced;}};
            libraries=map toString [f.pythonOpenssl f.prerequisites.zlib f.prerequisites.bzip2 f.prerequisites.xz];
            native=map toString [p.libc p.libgcc p.libstdcxx];
            shell="${{f.composition.bash}}/bin/bash";
            perl="${{f.prerequisites.perl}}/bin/perl";
            ninja="${{f.tools.ninja}}/bin/ninja"; cmake="${{f.prior.cmake}}/bin/cmake";
            pkgConfig="${{f.tools.pkgConfig}}/bin/pkg-config";
            pythonEvidence=toString t.python.evidence; mesonEvidence=toString t.meson.evidence;
            mesonSource=toString f.sources.meson; pythonSource=toString f.sources.python;
            loader="${{p.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{b.gnu-binutils}}/bin/readelf"; }}''')
    permitted = set(m['native'] + m['libraries'] + list(m['packages'].values()))
    assert permitted <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    files, failures = boundary.scan(m['packages'].values(), permitted, m['loader'], m['readelf'])
    for package in m['packages'].values():
        for path in Path(package).rglob('*'):
            if path.is_symlink() and not strict.within(str(path.resolve()),permitted):
                failures.append('Escaping installed link: '+str(path))
    required = {'_ssl': ['libssl.so.3','libcrypto.so.3'], '_hashlib':['libcrypto.so.3'],
                'zlib':['libz.so.1'], '_bz2':['libbz2.so.1.0'], '_lzma':['liblzma.so.5']}
    py = Path(m['packages']['python'])
    for module, libraries in required.items():
        paths = list((py/'lib/python3.12/lib-dynload').glob(module + '.*.so'))
        assert len(paths) == 1
        if any(not files[str(paths[0])]['needed'].get(lib) for lib in libraries):
            failures.append('Missing actual provider: ' + module)
    installed={}
    for name, relative in [('pythonConsumer','bin/embed'),('mesonConsumer','bin/answer'),('helperConsumer','bin/answer')]:
        p=subprocess.run([str(Path(m['packages'][name])/relative)],env={},text=True,capture_output=True,timeout=10)
        if p.returncode or p.stdout.strip()!='42': failures.append('Installed env-i execution failed: '+name)
        installed[name]=dict(status=p.returncode,stdout=p.stdout,stderr=p.stderr,environment={})
    known = strict.origin_paths(origin)
    raw = audit.nix_json('path-info', '--json', '--recursive', *m['packages'].values())
    closure = sorted(raw if isinstance(raw, dict) else (p['path'] for p in raw))
    if set(closure) - set(known): failures.append('Unclassified full reference closure')
    scripts = {}
    for name in ['python','meson','selectedMeson','traced','pythonOpenssl']:
        for path in (Path(m['packages'][name])/'bin').glob('*'):
            if not path.is_file() or path.is_symlink(): continue
            head=path.read_bytes().split(b'\n',1)[0]
            if head.startswith(b'#!'):
                interpreter=head[2:].decode().split()[0]
                if interpreter not in [m['shell'], m['perl'], str(py/'bin/python3'), str(py/'bin/python3.12')]:
                    failures.append('Unexpected script interpreter: ' + str(path))
                scripts[str(path)]=interpreter
    wrappers={}
    for name in ['meson','selectedMeson']:
        expected=(ROOT/'../pkgs/build-tools/meson/meson.sh').read_text()
        tools={k:m[k] for k in ['ninja','cmake','pkgConfig']}
        if name=='selectedMeson':
            tools={k:m['packages']['traced']+'/bin/'+({'pkgConfig':'pkg-config'}.get(k,k)) for k in tools}
        for key,value in dict(tools,bash=m['shell'],python=str(py/'bin/python3'),out=m['packages'][name]).items():
            expected=expected.replace('@'+key+'@',value)
        actual=(Path(m['packages'][name])/'bin/meson').read_text()
        if expected!=actual:failures.append('Launcher default/input mismatch: '+name)
        wrappers[name]=dict(sha256=hashlib.sha256(actual.encode()).hexdigest(),tools=tools)
    maps = {}
    for name, root in [('python',m['pythonEvidence']),('meson',m['mesonEvidence'])]:
        for path in Path(root).glob('*loader.log'):
            text=path.read_text()
            if path.name == 'python-loader.log':
                paths=sorted(set(re.findall(r'(/nix/store/[^\s]+)',text)))
            else: paths=sorted(set(re.findall(r'calling init: (/\S+)',text)))
            if not paths or any(not strict.owned_executable(p,permitted) for p in paths):
                failures.append('Foreign/empty actual process maps: ' + str(path))
            maps[name+'/'+path.name]=paths
    if len(maps)!=3: failures.append('Missing actual installed process maps')
    units=json.loads((Path(m['mesonEvidence'])/'summary.json').read_text())
    python=json.loads((Path(m['pythonEvidence'])/'summary.json').read_text())
    data=zip_data(Path(m['packages']['meson'])/'libexec/meson.pyz',m['mesonSource'],str(py))
    return dict(schema=1,failures=failures,files=files,permittedNative=sorted(permitted),
        priorRuntimeFiles=len(prior['files']),fullReferenceClosure=closure,
        referenceRoles={p:dict(origin=known.get(p),role='selected-native-generation' if p in permitted else 'development/build/module reference; no native executable permission') for p in closure},
        installedScripts=scripts,launcherBindings=wrappers,installedEnvI=installed,compressedZipappData=data,pythonLibraryData=python_data(py,m['pythonSource'],m['shell']),actualProcessMaps=maps,
        python=python,meson=units,
        limits='BUILD profile and bounded upstream subsets, not full conformance; development compiler closure never authorizes native compiler/musl execution.')


if __name__ == '__main__':
    result=run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result,indent=2,sort_keys=True))
    sys.exit(bool(result['failures']))
