"""Compile, execute and inspect the selected target, never the host defaults."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

src, out, evidence, gcc_source = map(Path, sys.argv[1:])
cc, cxx, cpp, readelf = (os.environ[k] for k in
                         ('TARGET_CC', 'TARGET_CXX_DRIVER', 'TARGET_CPP', 'TARGET_READELF'))
libc, rt, stdcxx = (os.environ[k] for k in ('TARGET_LIBC', 'TARGET_GCC', 'TARGET_CXX'))
loader = libc + '/lib/ld-linux-x86-64.so.2'
allowed = [libc + '/lib', rt, stdcxx + '/lib', str(out / 'lib')]
results = []


def call(name, args, expected=0, extra=None, stdin=None):
    p = subprocess.run(list(map(str, args)), env=extra or {}, input=stdin,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (evidence / (name + '.log')).write_text(p.stdout)
    results.append(dict(name=name, argv=list(map(str, args)), status=p.returncode,
                        expected=expected))
    (evidence / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    if p.returncode != expected:
        raise RuntimeError(f'{name}: status {p.returncode}, expected {expected}\n{p.stdout[-5000:]}')
    return p.stdout


def inspect(name, path, kind, cxx_needed=False):
    info = call(name + '-elf', [readelf, '-W', '-h', '-l', '-d', path])
    interp = re.findall(r'Requesting program interpreter: ([^\]]+)', info)
    needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', info)
    paths = re.findall(r'\((?:RPATH|RUNPATH)\).*\[([^\]]*)\]', info)
    if kind == 'static':
        assert not interp and not needed, (name, interp, needed)
        assert 'EXEC (Executable file)' in info
        return
    assert interp == ([loader] if kind != 'shared' else []), (name, interp)
    for value in paths:
        assert all(d in allowed for d in value.split(':')), (name, paths)
    assert paths, name
    if kind in ('pie', 'shared'):
        assert 'DYN (' in info, name
    else:
        assert 'EXEC (' in info, name
    listing = call(name + '-loader', [loader, '--list', path])
    for soname in needed:
        if soname.startswith('libstdc++'):
            directory = stdcxx + '/lib'
        elif soname.startswith('libgcc_s'):
            directory = rt
        elif soname.startswith('libtarget'):
            directory = str(out / 'lib')
        else:
            directory = libc + '/lib'
        if soname == 'ld-linux-x86-64.so.2':
            assert loader + ' (0x' in listing, (name, listing)
        else:
            assert f'{soname} => {directory}/' in listing, (name, soname, listing)
    if cxx_needed:
        assert 'libstdc++.so.6' in needed, (name, needed)


(Path('zero.c')).write_text('int exported(void) { return 42; }\nint main(void) { return exported()!=42; }\n')
(Path('cxx.cc')).write_text('#include <string>\nint exported() { return 42; }\nint main() { return std::string("target").size()!=6; }\n')
for driver, tag in [(cc, 'c'), (cxx, 'cxx'), (cpp, 'cpp')]:
    assert call(tag + '-sysroot', [driver, '-print-sysroot']).strip() == libc
    for lib, expected in [('libgcc.a', rt), ('libgcc_s.so.1', rt),
                          ('libstdc++.so', stdcxx + '/lib'), ('crt1.o', libc + '/lib')]:
        value = call(tag + '-query-' + lib, [driver, '-print-file-name=' + lib]).strip()
        assert Path(value).resolve() == (Path(expected) / lib).resolve(), (tag, lib, value)
    value = call(tag + '-libgcc-query', [driver, '-print-libgcc-file-name']).strip()
    assert Path(value).resolve() == (Path(rt) / 'libgcc.a').resolve()
    call(tag + '-cc1-query', [driver, '-print-prog-name=cc1'])
    specs = call(tag + '-effective-specs', [driver, '-dumpspecs'])
    assert libc + '/lib/ld-linux-x86-64.so.2' in specs and rt in specs and stdcxx in specs
Path('query.rsp').write_text('-dumpspecs')
assert call('response-effective-specs', [cc, '@query.rsp']) == specs
search = call('target-search', [cc, '-print-search-dirs'])
assert libc in search and 'M-G-G/lib/gcc/' not in search


for tag, driver, source in [('c', cc, 'zero.c'), ('cxx', cxx, 'cxx.cc')]:
    for mode, flags in [('dynamic', []), ('static', ['-static']),
                        ('pie', ['-fPIE', '-pie']), ('no-pie', ['-no-pie']),
                        ('shared', ['-fPIC', '-shared'])]:
        name = tag + '-' + mode
        path = out / ('lib/lib' + name + '.so' if mode == 'shared' else 'bin/' + name)
        log = call(name + '-link', [driver, '-v', '-Wl,-t,-t', *flags, source, '-o', path])
        # Every start/end object and C runtime selected by the real link trace
        # is from this generation. Host frontend paths may remain prior-GNU.
        for token in re.findall(r'/nix/store/[^\s"()]+', log):
            if re.search(r'/(?:crt[^/]*\.o|lib(?:gcc|stdc\+\+|c)[^/]*)$', token):
                resolved = str(Path(token).resolve())
                assert any(resolved.startswith(d + '/') for d in allowed), (name, token, resolved)
        inspect(name, path, mode)
        if mode != 'shared':
            call(name + '-run', [path])
    rd = out / 'bin' / (tag + '-rdynamic')
    call(tag + '-rdynamic-build', [driver, source, '-rdynamic', '-o', rd])
    syms = call(tag + '-rdynamic-symbols', [readelf, '--dyn-syms', '-W', rd])
    assert ('exported' if tag == 'c' else '_Z8exportedv') in syms

for mode in ['-m16', '-m32', '-mx32', '-mmusl', '-mbionic', '-muclibc', '-static-pie']:
    # m16 is a non-native ABI too, explicitly rejected by the selected adapter.
    call('reject-' + mode, [cc, mode, 'zero.c'], 64)
call('reject-hardening', [cc, '-c', 'zero.c'], 64, {'NIX_HARDENING_ENABLE': 'fortify'})
call('reject-mode-link', [cc, 'zero.c'], 64, {'NIX_CFLAGS_LINK': '-c'})
call('reject-comma-ld', [cc, 'zero.c'], 64, {'NIX_LDFLAGS': 'a,b'})

# Mixed language and preprocessing use the frontend selected by GCC for each
# input; C must never acquire C++ headers simply because another input is C++.
Path('mixed.c').write_text('_Static_assert(1,"C frontend"); int c_value(void) { return 42; }\n')
Path('mixed.cc').write_text('#include <vector>\nextern "C" int c_value();\nint main(){return std::vector<int>{c_value()}[0]!=42;}\n')
call('mixed-build', [cc, 'mixed.c', 'mixed.cc', '-lstdc++', '-o', 'mixed'])
call('mixed-run', ['./mixed'])
call('cpp-cxx', [cpp, '-x', 'c++', '-v', '-H', 'mixed.cc'])
call('x-cxx', [cc, '-x', 'c++', 'mixed.cc', '-x', 'c', 'mixed.c', '-lstdc++', '-o', 'mixed-x'])
call('x-cxx-run', ['./mixed-x'])
Path('headers.cc').write_text('#include <vector>\n#include <unwind.h>\n#include <pthread.h>\n')
trace = call('headers', [cxx, '-E', '-v', '-H', 'headers.cc'])
assert stdcxx + '/include/c++/16.2.0' in trace
assert libc + '/include' in trace
prefix = Path(cc).parent.parent / 'include'
assert (prefix / 'unwind.h').resolve() == Path(rt + '/include/unwind.h').resolve()
for file in prefix.iterdir():
    if file.name in ('unwind.h', 'gthr.h', 'gthr-posix.h', 'gthr-default.h'):
        assert str(file.resolve()).startswith(str(Path(rt).parent.parent.parent.parent) + '/')
search_order = trace.split('#include <...> search starts here:\n', 1)[1].split('End of search list.', 1)[0]
assert search_order.index(stdcxx + '/include/c++/16.2.0') < search_order.index(str(prefix))
# -B must not insert the intrinsic C header before its C++ compatibility wrapper.
Path('atomic.cc').write_text('#include <stdatomic.h>\nint main(){atomic_int value{1};return value.load()!=1;}\n')
call('atomic-cxx23-build', [cxx, '-std=c++23', 'atomic.cc', '-o', out / 'bin/atomic'])
call('atomic-cxx23-run', [out / 'bin/atomic'])
call('deps', [cc, '-M', 'mixed.c'])
call('assemble', [cc, '-S', 'mixed.c', '-o', 'mixed.s'])
# Startup/library suppression retains real GCC semantics.
Path('start.S').write_text('.global _start\n.text\n_start:\n mov $60,%rax\n xor %rdi,%rdi\n syscall\n')
for flag in ['-nostdlib', '-nostartfiles']:
    call(flag + '-link', [cc, flag, 'start.S', '-o', flag[1:]])
    call(flag + '-run', ['./' + flag[1:]])
call('nodefaultlibs-link', [cc, '-nodefaultlibs', 'zero.c', '-lc', '-lgcc', '-o', 'nodefaultlibs'])
call('nodefaultlibs-run', ['./nodefaultlibs'])

macros = [f'-DTARGET_LIBC="{libc}"', f'-DTARGET_GCC="{rt}"', f'-DTARGET_CXX="{stdcxx}"']
for file in ['gnu-target-maps.h', 'gnu-target-rtti.h', 'gnu-target-plugin.cc',
             'gnu-target-rtti.cc', 'gnu-target-locale.cc', 'gnu-cancel.c']:
    Path(file).write_bytes((src / file).read_bytes())
for static in [False, True]:
    tag = 'locale-static' if static else 'locale'
    path = out / 'bin' / tag
    call(tag + '-build', [cxx, '-std=c++20', '-pthread', *macros,
                          *(['-static', '-DSTATIC_PROBE'] if static else []), 'gnu-target-locale.cc', '-o', path])
    call(tag + '-run', [path])
    inspect(tag, path, 'static' if static else 'dynamic', not static)
call('cxx20-build', [cxx, '-std=c++20', src / 'consumer20.cc', '-o', out / 'bin/cxx20'])
call('cxx20-run', [out / 'bin/cxx20'])
plugin = out / 'lib/libtarget.so'
call('rtti-plugin-build', [cxx, '-shared', '-fPIC', 'gnu-target-plugin.cc', '-o', plugin])
call('rtti-build', [cxx, *macros, 'gnu-target-rtti.cc', '-L' + str(out / 'lib'), '-ltarget',
                    '-Wl,-rpath,' + str(out / 'lib'), '-o', out / 'bin/rtti'])
call('rtti-run', [out / 'bin/rtti'])
inspect('rtti', out / 'bin/rtti', 'dynamic', True)
# Cancellation must load the selected unwinder without an explicit DT_NEEDED.
s = Path('gnu-cancel.c').read_text().replace('puts("GNU C-only', 'target_maps(0, 1);\n    puts("GNU C-only')
Path('cancel.c').write_text(s)
call('cancel-build', [cc, '-pthread', *macros, '-include', 'gnu-target-maps.h', 'cancel.c', '-o', out / 'bin/cancel'])
info = call('cancel-needed', [readelf, '-d', out / 'bin/cancel'])
assert 'Shared library: [libgcc_s.so.1]' not in info
call('cancel-run', [out / 'bin/cancel'], extra={'LD_DEBUG': 'libs'})
inspect('cancel', out / 'bin/cancel', 'dynamic')
call('cancel-static-build', [cc, '-static', '-pthread', src / 'gnu-cancel.c', '-o', out / 'bin/cancel-static'])
call('cancel-static-run', [out / 'bin/cancel-static'])
inspect('cancel-static', out / 'bin/cancel-static', 'static')
call('forced-plugin-build', [cxx, '-fPIC', '-shared', src / 'gnu-plugin.cc', '-o', out / 'lib/libforced.so'])
forced = (src / 'gnu-unwind.cc').read_text().replace('std::puts("GNU shared', 'target_maps(1, 1);\n    std::puts("GNU shared')
Path('forced.cc').write_text(forced)
call('forced-build', [cxx, '-pthread', *macros, '-include', 'gnu-target-maps.h', 'forced.cc', '-ldl', '-o', out / 'bin/forced'])
call('forced-run', [out / 'bin/forced', out / 'lib/libforced.so'], extra={'LD_DEBUG': 'libs'})
# Inspect the new runtime DSOs themselves with the exact target loader.
for name, path in [('libgcc', Path(rt) / 'libgcc_s.so.1'),
                   ('libstdcxx', Path(stdcxx) / 'lib/libstdc++.so.6')]:
    inspect(name, path, 'shared')
# Run real, unmodified upstream tests under their explicit native prerequisites.
# This is a selected compile/run subset, not a DejaGNU/full-conformance claim.
suite = gcc_source / 'libstdc++-v3/testsuite'
selected = ['18_support/exception_ptr/current_exception.cc',
            '18_support/exception_ptr/rethrow_exception.cc',
            '30_threads/thread/cons/1.cc',
            '30_threads/thread/members/1.cc',
            '22_locale/ctype/is/wchar_t/1.cc']
upstream = []
for index, test in enumerate(selected):
    binary = './upstream-' + str(index)
    call('upstream-' + str(index) + '-compile', [cxx, '-std=c++11', '-pthread',
         '-I' + str(suite / 'util'), suite / test, '-o', binary])
    call('upstream-' + str(index) + '-run', [binary])
    upstream.append({'test': test, 'result': 'PASS'})
(evidence / 'upstream.json').write_text(json.dumps({'results': upstream,
    'counts': {'PASS': len(upstream), 'FAIL': 0, 'ERROR': 0, 'XPASS': 0, 'SKIP': 0},
    'harness': 'selected unmodified compile/run subset; not DejaGNU'}, indent=2) + '\n')
(evidence / 'summary.json').write_text(json.dumps({'result': 'PASS', 'assertions': len(results)}, indent=2) + '\n')
