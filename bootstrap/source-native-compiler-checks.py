"""Bounded raw-driver and source-tool projects; never a full GCC conformance suite."""
import json
import os
from pathlib import Path
import subprocess
import sys

out, evidence = map(Path, sys.argv[1:])
results = []


def call(name, args, expected=0, env=None):
    p = subprocess.run(list(map(str, args)), env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (evidence / (name + '.log')).write_text(p.stdout)
    results.append(dict(name=name, argv=list(map(str, args)), status=p.returncode, expected=expected))
    (evidence / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert p.returncode == expected, (name, p.returncode, p.stdout[-4000:])
    return p.stdout


cc, cxx = os.environ['CC'], os.environ['CXX']
assert cc == os.environ['EXPECTED_CC'].replace('/gcc', '/cc')
assert cxx == os.environ['EXPECTED_CXX'].replace('/g++', '/c++')
Path('raw.c').write_text('#include <stdio.h>\nint main(void){puts("42");return 0;}\n')
Path('raw.cc').write_text('#include <vector>\n#include <stdexcept>\nint main(){try {throw std::runtime_error("42");}catch(const std::exception &e){return std::vector<int>{42}[0]!=42;}}\n')
for language, driver, source in [('c', os.environ['RAW_CC'], 'raw.c'), ('cxx', os.environ['RAW_CXX'], 'raw.cc')]:
    for mode, flags in [('dynamic', []), ('static', ['-static']), ('pie', ['-fPIE', '-pie']), ('shared', ['-fPIC', '-shared'])]:
        for standard in (['c11'] if language == 'c' else ['c++14', 'c++20']):
            tag = f'raw-{language}-{standard}-{mode}'
            binary = out / 'bin' / tag
            call(tag + '-build', [driver, '-std=' + standard, *flags, source, '-o', binary])
            if mode != 'shared': call(tag + '-run', [binary], env={})
    call('raw-' + language + '-headers', [driver, '-v', '-E', source])
    specs = call('raw-' + language + '-specs', [driver, '-dumpspecs'])
    # Raw GCC -dumpspecs reports builtins, even when installed specs are active.
    installed = Path(driver).parent.parent / 'lib/gcc/x86_64-unknown-linux-gnu/16.2.0/specs'
    specs = installed.read_text()
    (evidence / ('raw-' + language + '-installed-specs.log')).write_text(specs)
    assert os.environ['NATIVE_LIBC'] in specs and os.environ['NATIVE_CXX'] in specs
Path('math.c').write_text('''#include <gmp.h>
#include <mpfr.h>
#include <mpc.h>
int main(void){mpz_t z;mpfr_t f;mpc_t c;mpz_init_set_ui(z,42);mpfr_init2(f,80);mpc_init2(c,80);mpfr_set_z(f,z,MPFR_RNDN);mpc_set_fr(c,f,MPC_RNDNN);int bad=mpfr_cmp_ui(mpc_realref(c),42);mpc_clear(c);mpfr_clear(f);mpz_clear(z);return bad;}
''')
call('math-build', [cc, 'math.c', '-lmpc', '-lmpfr', '-lgmp', '-o', out / 'bin/math'])
call('math-run', [out / 'bin/math'], env={})
# The project builds a native generator with the selected compiler, runs it,
# generates a header, compiles a C++14 consumer, and installs that consumer.
Path('generator.c').write_text('#include <stdio.h>\nint main(int n,char **v){FILE *f=fopen(v[1],"w");if(!f)return 1;fprintf(f,"#define VALUE 42\\n");return fclose(f);}\n')
Path('main.cc').write_text('#include "generated.h"\n#include <vector>\nint main(){return std::vector<int>{VALUE}[0]!=42;}\n')
Path('CMakeLists.txt').write_text('''cmake_minimum_required(VERSION 3.16)
project(candidate LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 14)
add_executable(generator generator.c)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/generated.h COMMAND generator ${CMAKE_CURRENT_BINARY_DIR}/generated.h DEPENDS generator)
add_executable(answer main.cc ${CMAKE_CURRENT_BINARY_DIR}/generated.h)
target_include_directories(answer PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
install(TARGETS answer DESTINATION bin)
''')
for tag, generator in [('make', 'Unix Makefiles'), ('ninja', 'Ninja')]:
    build = Path('build-' + tag)
    call(tag + '-configure', ['cmake', '-S', '.', '-B', build, '-G', generator, '-DCMAKE_INSTALL_PREFIX=' + str(out / tag)])
    cache = (build / 'CMakeCache.txt').read_text()
    assert 'CMAKE_C_COMPILER:FILEPATH=' + cc in cache
    assert 'CMAKE_CXX_COMPILER:FILEPATH=' + cxx in cache
    call(tag + '-build', ['cmake', '--build', build, '--verbose', '-j', os.environ['NIX_BUILD_CORES']])
    times = {str(p): p.stat().st_mtime_ns for p in [build/'generator', build/'answer', build/'generated.h']}
    call(tag + '-noop', ['cmake', '--build', build, '--verbose'])
    assert all(Path(p).stat().st_mtime_ns == t for p,t in times.items())
    # A content edit must rebuild the affected consumer, not the generator.
    Path('main.cc').write_text(Path('main.cc').read_text() + '\n// rebuild ' + tag + '\n')
    call(tag + '-rebuild', ['cmake', '--build', build, '--verbose'])
    assert (build/'answer').stat().st_mtime_ns != times[str(build/'answer')]
    assert (build/'generator').stat().st_mtime_ns == times[str(build/'generator')]
    call(tag + '-install', ['cmake', '--install', build])
    call(tag + '-installed', [out / tag / 'bin/answer'], env={})
    (evidence / (tag + '-CMakeCache.txt')).write_text(cache)
(evidence / 'summary.json').write_text(json.dumps(dict(result='PASS', assertions=len(results), limits='Focused raw and generator/project probes; not DejaGNU or compiler selfhosting.')) + '\n')
