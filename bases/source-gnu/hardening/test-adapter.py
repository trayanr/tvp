"""Bounded argv protocol and real selected GNU/glibc artifact controls."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location('adapter', sys.argv[1])
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
all_flags = list(a.SUPPORTED)


def prep(argv, env=None, program='gcc', flags=all_flags):
    return a.prepare(program, argv, env or {}, flags)


def reject(fn):
    try:
        fn()
    except ValueError:
        return
    raise AssertionError('expected rejection')


with tempfile.TemporaryDirectory() as work:
    os.chdir(work)
    Path('inner').write_text('-O0 -O2 -D _FORTIFY_SOURCE=1 -o "-O0"')
    Path('outer').write_text('@inner -x c "input with space.c"')
    args, env = prep(['@outer'], {'NIX_CFLAGS_COMPILE': '-O3', 'NIX_CFLAGS_LINK': '-O0', 'NIX_LDFLAGS': '-z now'})
    assert args == ['-fPIC', '-fstack-protector-strong', '-fno-strict-overflow', '-Wformat', '-Wformat-security', '-Werror=format-security', '-Wl,-z,relro', '-Wl,-z,now', '-O3', '-O0', '-O0', '-O2', '-D', '_FORTIFY_SOURCE=1', '-o', '-O0', '-x', 'c', 'input with space.c', '-Xlinker', '-z', '-Xlinker', 'now']
    assert not any(k.startswith('NIX_') for k in env)
    for opt, expected in [([], False), (['-O0'], False), (['-O2'], True), (['-O2', '-O0'], False), (['-O0', '-O2'], True), (['-Og'], True)]:
        assert ('-D_FORTIFY_SOURCE=2' in prep(opt + ['a.c'])[0]) == expected
    for macro in [['-U_FORTIFY_SOURCE'], ['-D_FORTIFY_SOURCE=0'], ['-D', '_FORTIFY_SOURCE=3'], ['-U', '_FORTIFY_SOURCE']]:
        assert '-D_FORTIFY_SOURCE=2' not in prep(['-O2'] + macro + ['a.c'])[0]
    assert '-D_FORTIFY_SOURCE=2' in prep(['a.c'], {'NIX_CFLAGS_COMPILE': '-O2'})[0]
    assert '-D_FORTIFY_SOURCE=2' not in prep(['-o', '-O2', 'a.c'])[0]
    for mode in ['-c', '-S', '-E', '-M', '-MM', '-fsyntax-only']:
        assert '-Wl,-z,now' not in prep([mode, '-O2', 'a.c'])[0]
    for mode in ['-static', '-r']:
        assert '-Wl,-z,now' not in prep([mode, '-O2', 'a.c'])[0]
    assert '-fPIC' not in prep(['-c', 'a.S'])[0]
    assert '-fPIC' not in prep(['-x', 'assembler', '-c', 'a'])[0]
    assert '-Wl,-z,now' in prep(['-shared', '-O2', 'a.c'])[0]
    assert '-Wl,-z,now' in prep(['-###', 'a.c'])[0]
    for query in ['--version', '-dumpmachine', '-dumpspecs', '-print-file-name=libc.so', '-v']:
        assert prep([query], {'NIX_CFLAGS_COMPILE': '-O2'})[0] == [query]
    assert prep(['a.c'], {'NIX_HARDENING_ENABLE': '', 'NIX_CFLAGS_COMPILE': '-O2'}) == (['a.c'], {'NIX_CFLAGS_COMPILE': '-O2'})
    assert prep(['--version'], program='ld')[0] == ['--version']
    assert prep(['a.o'], {'NIX_LDFLAGS': '-Llib'}, program='ld')[0] == ['-z', 'relro', '-z', 'now', '-Llib', 'a.o']
    for mode in ['-r', '-static']:
        assert prep([mode, 'a.o'], program='ld')[0] == [mode, 'a.o']
    assert prep(['-o', '-r', 'a.o'], program='ld')[0][:4] == ['-z', 'relro', '-z', 'now']
    for invalid in ['-m16', '-m32', '-mx32', '-static-pie']:
        reject(lambda: prep([invalid, 'a.c']))
    for opaque in [['-Wp,-D_FORTIFY_SOURCE=0'], ['-Xpreprocessor', '-U_FORTIFY_SOURCE'], ['-specs=hidden']]:
        reject(lambda: prep(opaque + ['a.c']))
    assert '-Wl,-z,now' not in prep(['-Wl,-r', 'a.o'])[0]
    reject(lambda: prep(['@missing']))
    reject(lambda: prep(['a.c'], {'NIX_HARDENING_ENABLE': 'pie'}))
    reject(lambda: prep(['a.c'], {'NIX_CFLAGS_LINK': '-c'}))
    reject(lambda: prep(['a.c'], {'NIX_LDFLAGS': 'a,b'}))
    reject(lambda: prep(['a.c'], {'NIX_CFLAGS_COMPILE': 'a\nb'}))
    reject(lambda: a.tokenize('"unterminated'))
    assert a.tokenize("'a\\b' \"c\\d\" a\\ b") == ['ab', 'cd', 'a b']
    # Execute the installed adapter against fake underlying tools, recording argv
    # and env. Shell punctuation and substitutions remain inert arguments.
    fake = Path(work) / 'fake'
    fake.mkdir()
    for name in ['gcc', 'g++', 'cpp', 'ld']:
        (fake / name).write_text('#!' + sys.executable + '\nimport json,os,sys\nprint(json.dumps([sys.argv[1:],dict(os.environ)]))\n')
        (fake / name).chmod(0o755)
    launcher = Path(work) / 'cc'
    launcher.write_text('#!' + sys.executable + '\nimport runpy\nrunpy.run_path(' + repr(sys.argv[1]) + ',init_globals={"PROGRAM":"cc","DRIVER":' + repr(str(fake)) + ',"BINTOOLS":' + repr(str(fake)) + ',"DEFAULTS":' + repr(all_flags) + '},run_name="__main__")\n')
    launcher.chmod(0o755)
    poison = '$(touch INJECTION);*`touch INJECTION`'
    result = subprocess.check_output([str(launcher), '-O2', '-DVALUE=' + poison, 'a.c'], env={**os.environ, 'NIX_CFLAGS_COMPILE': '-O1', 'NIX_HARDENING_ENABLE': 'fortify'})
    recorded, forwarded_env = json.loads(result)
    assert recorded == ['-D_FORTIFY_SOURCE=2', '-O1', '-O2', '-DVALUE=' + poison, 'a.c']
    assert 'NIX_CFLAGS_COMPILE' not in forwarded_env and 'NIX_HARDENING_ENABLE' not in forwarded_env
    assert not Path('INJECTION').exists()
    print('argv/mode/response/ordering/injection controls PASS')

    if len(sys.argv) < 5:
        sys.exit(0)
    hardened, legacy, readelf = sys.argv[2:5]
    linker = sys.argv[6] if len(sys.argv) > 6 else hardened
    clean = {k: v for k, v in os.environ.items() if not k.startswith('NIX_CFLAGS') and k not in ('NIX_HARDENING_ENABLE', 'NIX_LDFLAGS')}
    evidence = Path(sys.argv[5]) if len(sys.argv) > 5 else None
    if evidence:
        evidence.mkdir(parents=True, exist_ok=True)
    def run(args, **kwargs):
        result = subprocess.check_output(args, env=clean, stderr=subprocess.STDOUT, text=True, **kwargs)
        if evidence:
            with (evidence / 'invocations.jsonl').open('a') as f:
                f.write(json.dumps({'argv': args, 'stdout': result}) + '\n')
        return result
    def build(compiler, args, out):
        return run([compiler] + args + ['-o', out])
    def elf(path, option):
        return run([readelf, option, path])
    source = '#include <stdio.h>\n#include <string.h>\n__attribute__((noinline)) int f(char *p) { char b[32]; strcpy(b,p); puts(b); return b[0]; }\nint main(int n,char **v) { return n>1 ? f(v[1])==0 : 0; }\n'
    Path('tiny.c').write_text(source)
    results = {}
    for language, command in [('C', 'cc'), ('C++', 'c++')]:
        for label, optimization, enabled in [('hardened', '-O2', True), ('O0', '-O0', False), ('default', None, False)]:
            out = language + label
            build(hardened + '/bin/' + command, ([optimization] if optimization else []) + ['tiny.c'], out)
            dyn, syms = elf(out, '-dW'), elf(out, '-sW')
            assert 'BIND_NOW' in dyn and '__stack_chk_fail' in syms
            assert ('__strcpy_chk' in syms) == enabled
            run(['./' + out])
            results[out] = {'bindnow': True, 'stackprotector': True, 'fortify': enabled}
        out = language + 'legacy'
        build(legacy + '/bin/' + command, ['-O2', 'tiny.c'], out)
        assert 'BIND_NOW' not in elf(out, '-dW')
        assert '__strcpy_chk' not in elf(out, '-sW') and '__stack_chk_fail' not in elf(out, '-sW')
        out = language + 'explicit-off'
        build(hardened + '/bin/' + command, ['-O2', '-D_FORTIFY_SOURCE=0', '-fno-stack-protector', '-Wl,-z,lazy', 'tiny.c'], out)
        assert 'BIND_NOW' not in elf(out, '-dW') and '__strcpy_chk' not in elf(out, '-sW') and '__stack_chk_fail' not in elf(out, '-sW')
        trace = run([hardened + '/bin/' + command, '-###', '-O2', 'tiny.c'])
        assert '-fstack-protector-strong' in trace and '-z now' in trace
    # Real nested responses exercise effective optimization and macro decisions.
    Path('real-inner').write_text('-O0 -O2 -o response tiny.c')
    Path('real-outer').write_text('@real-inner')
    run([hardened + '/bin/cc', '@real-outer'])
    assert '__strcpy_chk' in elf('response', '-sW')
    Path('real-inner').write_text('-O2 -O0 -o response-off tiny.c')
    run([hardened + '/bin/cc', '@real-outer'])
    assert '__strcpy_chk' not in elf('response-off', '-sW')
    Path('macro.c').write_text('int pic = __PIC__;\n')
    macros = run([hardened + '/bin/cc', '-O2', '-dM', '-E', 'macro.c'])
    assert '#define __PIC__ 2' in macros and '#define _FORTIFY_SOURCE 2' in macros
    Path('format.c').write_text('#include <stdio.h>\nvoid f(char *p) { printf(p); }\n')
    bad = subprocess.run([hardened + '/bin/cc', '-c', 'format.c'], env=clean, capture_output=True, text=True)
    assert bad.returncode != 0 and 'format-security' in bad.stderr
    run([hardened + '/bin/cc', '-Wno-error=format-security', '-c', 'format.c'])
    # Query output remains byte-identical; -### above is intentionally different.
    for query in ['-dumpmachine', '-dumpspecs']:
        assert run([hardened + '/bin/cc', query]) == run([legacy + '/bin/cc', query])
    Path('shared.c').write_text('int data; int *address(void) { return &data; }\n')
    build(hardened + '/bin/cc', ['-shared', '-O2', 'shared.c'], 'shared.so')
    assert 'DYN' in elf('shared.so', '-hW') and 'TEXTREL' not in elf('shared.so', '-dW')
    build(hardened + '/bin/cc', ['-O2', '-c', 'tiny.c'], 'tiny.o')
    run([linker + '/bin/ld', '-shared', 'tiny.o', '-o', 'direct.so'])
    assert 'BIND_NOW' in elf('direct.so', '-dW') and 'GNU_RELRO' in elf('direct.so', '-lW')
    run([linker + '/bin/ld', '-r', 'tiny.o', '-o', 'reloc.o'])
    assert 'REL ' in elf('reloc.o', '-hW') and 'BIND_NOW' not in elf('reloc.o', '-dW')
    # GCC static linking is exercised and kept explicitly outside dynamic checks.
    build(hardened + '/bin/cc', ['-static', '-O2', 'tiny.c'], 'static')
    assert 'There is no dynamic section' in elf('static', '-dW')
    print(json.dumps(results, sort_keys=True))
    print('real C/C++/shared/direct-ld/static/relocatable controls PASS')
