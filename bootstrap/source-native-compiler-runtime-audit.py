"""New compiler permissions, separately from old build tools and reference closure."""
import importlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import audit

ROOT = Path(__file__).resolve().parent
strict = importlib.import_module('gnu-runtime-audit')
boundary = importlib.import_module('source-cmake-prerequisite-runtime-audit')


def validate_maps(paths, permitted):
    if not paths or any(not strict.owned_executable(p, permitted) for p in paths):
        raise ValueError('Empty or foreign compiler process maps')


def process_maps(driver, language, permitted):
    # Hold the frontend on an open stdin pipe, observe real /proc maps, then
    # finish the same finite compilation. No debugger or external tool injected.
    p = subprocess.Popen([driver, '-E', '-x', language, '-'], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={})
    deadline = time.monotonic() + 10
    maps = {}
    try:
        while time.monotonic() < deadline:
            children = Path(f'/proc/{p.pid}/task/{p.pid}/children').read_text().split()
            for pid in [str(p.pid)] + children:
                path = Path(f'/proc/{pid}/maps')
                if not path.exists(): continue
                lines = path.read_text().splitlines()
                paths = sorted({line.split()[-1] for line in lines if '/nix/store/' in line and 'x' in line.split()[1]})
                validate_maps(paths, permitted)
                maps[pid] = dict(exe=str(Path(f'/proc/{pid}/exe').resolve()), executableMappings=paths)
            if any('/cc1' in v['exe'] for v in maps.values()): break
            time.sleep(0.02)
        else:
            raise ValueError('No held native frontend observed')
    finally:
        stdout, stderr = p.communicate(b'int value;\n', timeout=10)
    assert p.returncode == 0, stderr
    return dict(processes=maps, status=p.returncode, stdout=stdout.decode(), stderr=stderr.decode())


def run(origin):
    if origin['failures']: raise ValueError('Construction audit failed')
    prior = importlib.import_module('source-python-meson-runtime-audit').run(origin)
    if prior['failures']: raise ValueError('Prior strict runtime audit failed')
    m = audit.nix_json('eval', '--json', '--impure', '--expr', f'''
      let t=import {ROOT}/source-native-compiler-tests.nix {{}}; f=t.f;
          b=import {ROOT} {{}};
      in {{ packages=builtins.mapAttrs (_: x: toString x) {{inherit (f) compiler driver; inherit (t) a a11 libraryB libraryB11 probe project stepped consumer override edited customized protocol constructorRebound baseRebound environmentRebound stepRebound;}};
            native=map toString [f.profile.libc f.profile.libgcc f.profile.libstdcxx f.gmp f.mpfr f.mpc];
            loader="${{f.profile.libc}}/lib/ld-linux-x86-64.so.2";
            readelf="${{b.gnu-binutils}}/bin/readelf";
            compilerEvidence=toString f.compiler.evidence;
            probeEvidence=toString t.probe.evidence; projectEvidence=toString t.project.evidence;
            reboundEvidence=builtins.mapAttrs (_: x: toString x.evidence) {{ inherit (t) constructorRebound baseRebound environmentRebound stepRebound; }};
            reusedLinkerNative=map toString [b.gnu-libc b.gnu-binutils];
            reusedTools=builtins.mapAttrs (_: x: toString x) (f.tools // {{ binutils=f.binutils; shell=f.composition.bash; }});
      }}''')
    # Shell/Make/Binutils retain their earlier executable generation, recorded
    # by the strict prior audit. They are NOT native compiler ELF permissions.
    permitted = set(m['native'] + list(m['packages'].values()))
    assert permitted <= strict.executable_outputs(origin)
    assert not permitted & set(origin['runtimeForbiddenExecutableRoots'])
    raw = Path(m['packages']['compiler'])
    scan_roots = [str(raw/'bin'), str(raw/'libexec')]
    scan_roots += [v for k,v in m['packages'].items() if k not in ('compiler','driver')]
    files, failures = boundary.scan(scan_roots, permitted, m['loader'], m['readelf'])
    for required in ['bin/gcc', 'libexec/gcc/x86_64-unknown-linux-gnu/16.2.0/cc1',
                     'libexec/gcc/x86_64-unknown-linux-gnu/16.2.0/cc1plus',
                     'libexec/gcc/x86_64-unknown-linux-gnu/16.2.0/collect2']:
        if str(raw/required) not in files: failures.append('Missing new compiler ELF: ' + required)
    known = strict.origin_paths(origin)
    closure_raw = audit.nix_json('path-info', '--json', '--recursive', *m['packages'].values())
    closure = sorted(closure_raw if isinstance(closure_raw,dict) else (x['path'] for x in closure_raw))
    if set(closure) - set(known): failures.append('Unclassified compiler development reference closure')
    generators = {}
    for file in (Path(m['compilerEvidence'])/'generators').glob('*.elf'):
        text = file.read_text()
        assert re.findall(r'Requesting program interpreter: ([^\]]+)', text) == [m['loader']]
        paths = re.findall(r'\((?:RPATH|RUNPATH)\).*\[([^\]]*)\]', text)
        assert paths
        for group in paths:
            for path in group.split(':'):
                assert strict.within(path, permitted), (file, path)
        generators[file.name] = dict(needed=re.findall(r'\(NEEDED\).*\[([^\]]+)\]',text), search=paths)
    assert len(generators) > 10
    loader_log = (Path(m['compilerEvidence'])/'generators/genmodes.loader').read_text()
    loaded = re.findall(r'calling init: (/\S+)', loader_log)
    validate_maps(loaded, permitted)
    maps = {lang: process_maps(str(raw/'bin/gcc'), lang, permitted) for lang in ['c','c++']}
    # Actual loader execution of the newly installed collect2 (may print usage),
    # with raw status recorded rather than treating it as a compiler test.
    p = subprocess.Popen([str(raw/'libexec/gcc/x86_64-unknown-linux-gnu/16.2.0/collect2'), '--help'],
                         env={'LD_DEBUG':'libs'}, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate(timeout=10)
    assert p.returncode == 0
    # collect2 invokes the explicitly reused ld. Classify each real process
    # separately: the linker's earlier libc does not authorize collect2 to use it.
    groups = {}
    for pid, path in re.findall(r'^\s*(\d+):\s+calling init: (/\S+)', stderr, re.M):
        groups.setdefault(pid, []).append(path)
    paths = groups.pop(str(p.pid))
    validate_maps(paths, permitted)
    assert groups
    linker_permitted = set(m['reusedLinkerNative'])
    assert linker_permitted <= strict.executable_outputs(origin)
    for child_paths in groups.values(): validate_maps(child_paths, linker_permitted)

    traces = {}
    for name, root in m['reboundEvidence'].items():
        lines = (Path(root)/'compiler-trace.log').read_text().splitlines()
        assert len(lines) > 10
        assert all(line.startswith(m['packages']['driver']+'/bin/') for line in lines)
        traces[name] = lines
    summaries = {k: json.loads((Path(m[k+'Evidence'])/'summary.json').read_text()) for k in ['probe','project']}
    assert all(s['result']=='PASS' for s in summaries.values())
    return dict(schema=1, failures=failures, files=files, permittedNative=sorted(permitted),
        priorRuntimeFiles=len(prior['files']), reusedToolRoles=m['reusedTools'],
        fullReferenceClosure=closure,
        referenceRoles={p:dict(origin=known.get(p),role='selected-native-compiler-generation' if p in permitted else 'declared earlier-generation tool or development reference; no compiler ELF permission') for p in closure},
        generators=generators, generatorActualLoader=loaded, actualProcessMaps=maps,
        collect2ActualLoader=dict(status=p.returncode,stdout=stdout,stderr=stderr,paths=paths,reusedLinkerProcesses=groups,reusedLinkerPermissions=sorted(linker_permitted)),
        summaries=summaries, rebindingExecutionTraces=traces, limits='Reduced checkpoint; no DejaGNU, full GCC parity, bootstrap comparison, selfhosting, fixed point, reproducibility or DDC claim.')


if __name__ == '__main__':
    result = run(json.loads(Path(sys.argv[1]).read_text()))
    print(json.dumps(result,indent=2,sort_keys=True))
    sys.exit(bool(result['failures']))
