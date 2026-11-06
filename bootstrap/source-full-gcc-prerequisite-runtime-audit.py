"""Require the native compiler observer, then independently bound new ELF roles."""
import importlib
import json
from pathlib import Path
import re
import subprocess
import sys
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
boundary = importlib.import_module('source-cmake-prerequisite-runtime-audit')


def require_paths(paths, permitted):
    if not paths or any(not strict.owned_executable(p, permitted) for p in paths):
        raise ValueError('Empty or foreign prerequisite execution mappings')


def run(origin):
    if origin['failures']:
        raise ValueError('Construction audit failed')
    prior = importlib.import_module('source-native-compiler-runtime-audit').run(origin)
    if prior['failures']:
        raise ValueError('Previous native compiler runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let t=import {ROOT}/source-full-gcc-prerequisite-tests.nix {{}}; f=t.f;
      in {{ packages=builtins.mapAttrs (_: x: toString x) {{inherit (f) isl libxcrypt which ncurses texinfo; consumer=t.consumer;}};
            native=map toString [f.native.profile.libc f.native.profile.libgcc f.native.profile.libstdcxx f.gmp f.perl];
            loader="${{f.native.profile.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{f.tools.binutils}}/bin/readelf";
            evidence=toString t.consumer.evidence;
            shell=toString f.tools.bash; perl=toString f.perl;
      }}''')
    permitted = set(m['native']+list(m['packages'].values()))
    assert permitted <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    files, failures = boundary.scan(list(m['packages'].values()), permitted, m['loader'], m['readelf'])
    known = strict.origin_paths(origin)
    raw = audit.nix_json('path-info', '--json', '--recursive', *m['packages'].values())
    closure = sorted(raw if isinstance(raw, dict) else (x['path'] for x in raw))
    if set(closure)-set(known):
        failures.append('Unclassified prerequisite development reference closure')
    scripts = {}
    for package in m['packages'].values():
        for path in (Path(package)/'bin').glob('*'):
            if not path.is_file() or path.is_symlink(): continue
            with path.open('rb') as f: head=f.read(512)
            if head.startswith(b'#!'):
                interpreter=head.split(b'\n',1)[0][2:].decode().split()[0]
                if not strict.owned_executable(interpreter, {m['shell'],m['perl']}):
                    failures.append('Foreign installed interpreter: '+str(path))
                scripts[str(path)]=interpreter
    commands = json.loads((Path(m['evidence'])/'commands.json').read_text())
    actual = []
    for command in commands:
        groups = {}
        for pid, path in re.findall(r'^\s*(\d+):\s+calling init: (/\S+)', command['stderr'], re.M):
            groups.setdefault(pid, []).append(path)
        for paths in groups.values(): require_paths(paths, permitted)
        if groups: actual.append(dict(args=command['args'], processes=groups))
    assert len(actual) >= 8
    maps = [c['stdout'] for c in commands if '/proc/self/maps' in ' '.join(c['args'])]
    assert len(maps) == 1
    mapped = sorted({line.split()[-1] for line in maps[0].splitlines()
                     if '/nix/store/' in line and 'x' in line.split()[1]})
    require_paths(mapped, permitted)
    assert any(p.startswith(m['packages']['texinfo']+'/') and p.endswith('.so') for p in mapped)
    interfaces = {}
    for name in ['isl','libxcrypt','ncurses']:
        root=Path(m['packages'][name])
        archives=list((root/'lib').glob('*.a'))
        assert archives
        interfaces[name]=dict(archives={str(a):subprocess.check_output([m['readelf'],'-h',str(a)],text=True) for a in archives},
            headers=sorted(str(p.relative_to(root)) for p in (root/'include').rglob('*.h')),
            pkgconfig={p.name:p.read_text() for p in (root/'lib/pkgconfig').glob('*.pc')})
    summary=json.loads((Path(m['evidence'])/'summary.json').read_text())
    assert summary['result']=='PASS'
    return dict(schema=1, failures=failures, files=files, permittedNative=sorted(permitted),
        previousRuntimeFiles=len(prior['files']), actualLoaderExecutions=actual, parserProcessMaps=mapped,
        installedScripts=scripts, interfaces=interfaces, summary=summary, fullReferenceClosure=closure,
        referenceRoles={p:dict(origin=known.get(p),role='new-prerequisite-native-generation' if p in permitted else 'construction/development reference; no new ELF permission') for p in closure})


if __name__ == '__main__':
    result=run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result,indent=2,sort_keys=True))
    sys.exit(bool(result['failures']))
