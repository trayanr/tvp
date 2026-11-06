"""Require prerequisite observers, then independently inspect installed harness ELF.

Construction tools and development references grant no native-generation runtime
permission. Script interpreters retain their explicitly reused tool roles.
"""
import importlib
import json
from pathlib import Path
import re
import sys
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
boundary = importlib.import_module('source-cmake-prerequisite-runtime-audit')
require_paths = importlib.import_module('source-full-gcc-prerequisite-runtime-audit').require_paths


def run(origin):
    if origin['failures']:
        raise ValueError('Construction audit failed')
    prior = importlib.import_module('source-full-gcc-prerequisite-runtime-audit').run(origin)
    if prior['failures']:
        raise ValueError('Prior prerequisite runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let t=import {ROOT}/source-gcc-test-harness-tests.nix {{}}; f=t.f;
      in {{ packages=builtins.mapAttrs (_: x: toString x) {{inherit (f) tcl expect dejagnu flock; consumer=t.consumer;}};
            native=map toString [f.native.profile.libc f.native.profile.libgcc f.native.profile.libstdcxx f.prerequisites.zlib];
            loader="${{f.native.profile.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{f.tools.binutils}}/bin/readelf";
            evidence=toString t.consumer.evidence;
            shell=toString f.tools.bash; perl=toString f.prerequisites.perl; }}''')
    permitted = set(m['native'] + list(m['packages'].values()))
    assert permitted <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    files, failures = boundary.scan(list(m['packages'].values()), permitted, m['loader'], m['readelf'])
    known = strict.origin_paths(origin)
    raw = audit.nix_json('path-info', '--json', '--recursive', *m['packages'].values())
    closure = sorted(raw if isinstance(raw, dict) else (x['path'] for x in raw))
    if set(closure)-set(known):
        failures.append('Unclassified harness reference closure')
    scripts = {}
    for package in m['packages'].values():
        for path in (Path(package)/'bin').glob('*'):
            if not path.is_file() or path.is_symlink():
                continue
            with path.open('rb') as stream:
                head = stream.read(512)
            if head.startswith(b'#!'):
                interpreter = head.split(b'\n', 1)[0][2:].decode().split()[0]
                if not strict.owned_executable(interpreter, {m['shell'], m['perl'], m['packages']['expect']}):
                    failures.append('Foreign installed interpreter: '+str(path))
                scripts[str(path)] = interpreter
    commands = json.loads((Path(m['evidence'])/'commands.json').read_text())
    actual = []
    for command in commands:
        groups = {}
        for pid, path in re.findall(r'^\s*(\d+):\s+calling init: (/\S+)', command['stderr'], re.M):
            groups.setdefault(pid, []).append(path)
        for paths in groups.values():
            require_paths(paths, permitted)
        if groups:
            actual.append(dict(args=command['args'], processes=groups))
    assert len(actual) >= 3
    maps = (Path(m['evidence'])/'extension-maps.log').read_text()
    mapped = sorted({line.split()[-1] for line in maps.splitlines()
                     if '/nix/store/' in line and 'x' in line.split()[1]})
    require_paths(mapped, permitted)
    assert any(p.startswith(m['packages']['expect']+'/') for p in mapped)
    tcl = m['packages']['tcl']
    assert any(any(n.startswith('libz.so') for n in info['needed']) for p, info in files.items() if p.startswith(tcl+'/'))
    assert any('libgcc_s.so.1' in info['needed'] for p, info in files.items() if p.startswith(tcl+'/'))
    summary = json.loads((Path(m['evidence'])/'summary.json').read_text())
    assert summary['result'] == 'PASS'
    return dict(schema=1, failures=failures, files=files, permittedNative=sorted(permitted),
                priorRuntimeFiles=len(prior['files']), actualLoaderExecutions=actual,
                extensionProcessMaps=mapped, installedScripts=scripts, summary=summary,
                referenceClosure=closure, referenceRoles={p: dict(origin=known.get(p),
                    role='harness-native' if p in permitted else 'construction/development; no new ELF permission') for p in closure})


if __name__ == '__main__':
    result = run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
