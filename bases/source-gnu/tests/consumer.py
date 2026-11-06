"""Finite compiler/discovery/build-system checks with no host search fallback."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

out, evidence = map(Path, sys.argv[1:3])
m = json.loads(sys.argv[3]); t = m['tools']; p = m['packages']
out.mkdir(); evidence.mkdir()
records = []
env = dict(os.environ)
assert not any(k in env for k in ['LD_LIBRARY_PATH', 'LD_PRELOAD', 'PYTHONPATH'])
assert all('/usr' not in x and '/bin' != x for x in env['PATH'].split(':'))
def run(name, args, extra=None, expected=0):
    result = subprocess.run(list(map(str, args)), text=True, capture_output=True, env=env | (extra or {}))
    records.append(dict(name=name,args=list(map(str,args)),status=result.returncode,stdout=result.stdout,stderr=result.stderr))
    (evidence/'commands.json').write_text(json.dumps(records, indent=2)+'\n')
    if result.returncode != expected:
        raise RuntimeError(f'{name}: {result.returncode}\n{result.stdout}\n{result.stderr}')
    return result.stdout
pc = t['pkgConfig']+'/bin/pkg-config'
flags = shlex.split(run('public-pkg-config', [pc,'--cflags','--libs','mpc','mpfr','gmpxx']))
assert all('-I'+p[x]+'/include' in flags for x in ['gmp','mpfr','mpc'])
cc, cxx = env['CC'], env['CXX']
fixtures = Path(m['fixtures'])
for language, driver in [('c',cc),('cc',cxx)]:
    target = out/('arithmetic-'+language)
    run('compile-'+language,[driver,fixtures/('arithmetic.'+language),*flags,'-o',target])
    run('run-'+language,[target])
# Static archives from the candidate-built libraries; libc/C++ runtime stay dynamic.
archive = out/'arithmetic-archives'
includes = [x for x in flags if x.startswith('-I')]
run('compile-archives',[cxx,fixtures/'gmp.cc',*includes,p['gmp']+'/lib/libgmpxx.a',p['gmp']+'/lib/libgmp.a','-lm','-o',archive])
run('run-archives',[archive])
# Prove CC replacement actually executes a controlled forwarding compiler.
sentinel = Path('cc-forward'); marker = Path('cc-used').resolve()
sentinel.write_text('#!'+t['bash']+'/bin/bash\nprintf selected > '+str(marker)+'\nexec '+cc+' "$@"\n'); sentinel.chmod(0o755)
run('forwarded-compiler',[str(sentinel.resolve()),fixtures/'arithmetic.c',*flags,'-o',out/'forwarded'])
assert marker.read_text() == 'selected'
run('run-forwarded',[out/'forwarded'])
# CMake's selected provider supplies its search policy. Both native generators
# build/test/install the same real JSON-C consumer.
for generator, tool in [('Unix Makefiles', t['make']+'/bin/make'),('Ninja',t['ninja']+'/bin/ninja')]:
    build = Path('cmake-'+generator.split()[0]); prefix = out/build.name
    run('cmake-configure-'+generator,[t['cmake']+'/bin/cmake','-S',fixtures,'-B',build,'-G',generator,'-DCMAKE_MAKE_PROGRAM='+tool,'-DCMAKE_INSTALL_PREFIX='+str(prefix),'-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF','-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF','-DPKG_CONFIG_EXECUTABLE='+pc])
    run('cmake-build-'+generator,[t['cmake']+'/bin/cmake','--build',build,'--parallel','4'])
    run('cmake-test-'+generator,[t['cmake']+'/bin/ctest','--test-dir',build,'--output-on-failure'])
    run('cmake-install-'+generator,[t['cmake']+'/bin/cmake','--install',build])
    run('cmake-installed-'+generator,[prefix/'bin/json-consumer'])
# Explicit native tools; Meson never searches for a host Python/pkg-config.
Path('native.ini').write_text('[binaries]\nc = '+repr(cc)+'\ncpp = '+repr(cxx)+'\npkg-config = '+repr(pc)+'\n')
run('meson-setup',[t['meson']+'/bin/meson','setup','meson-build',fixtures,'--native-file','native.ini','--prefix',out/'meson','--wrap-mode=nodownload'])
run('meson-build',[t['ninja']+'/bin/ninja','-C','meson-build','-j4'])
run('meson-test',[t['meson']+'/bin/meson','test','-C','meson-build','--print-errorlogs'])
run('meson-install',[t['meson']+'/bin/meson','install','-C','meson-build'])
for name in ['native-c','native-cxx']: run('installed-'+name,[out/'meson/bin'/name])
readelf = t['binutils']+'/bin/readelf'; loader = m['libc']+'/lib/ld-linux-x86-64.so.2'
elf = {}
for f in sorted(out.rglob('*')):
    if not f.is_file() or f.read_bytes()[:4] != b'\x7fELF': continue
    program = run('program-'+f.name,[readelf,'-l',f]); dynamic = run('dynamic-'+f.name,[readelf,'-d',f])
    listing = run('loader-'+f.name,[loader,'--list',f])
    assert loader in program
    assert '/usr/' not in listing and '/lib64/' not in listing
    if f.name in ['arithmetic-cc','arithmetic-archives','native-cxx']:
        assert m['compiler'] in listing and 'libstdc++.so.6' in listing
    if f.name == 'arithmetic-archives': assert all('lib'+x+'.so' not in dynamic for x in ['mpc','mpfr','gmp'])
    elf[str(f.relative_to(out))] = dict(program=program,dynamic=dynamic,loader=listing)
(evidence/'elf.json').write_text(json.dumps(elf,indent=2)+'\n')
(evidence/'summary.json').write_text(json.dumps(dict(commands=len(records),elfs=len(elf),publicTransitiveDiscovery=True,staticArchives=True,cmakeGenerators=2,mesonNative=True,forwardedCompiler=True,ambientProviders=False),indent=2)+'\n')
