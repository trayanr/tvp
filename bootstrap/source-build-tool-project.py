"""Installed pkg-config discovery and Ninja execution, without eval or host flags."""
import io
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

mode, evidence = sys.argv[1:3]
evidence = Path(evidence)
evidence.mkdir(exist_ok=True)

def run(label, argv, *, expected=0, env=None):
    p = subprocess.run(argv, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (evidence / (label + '.log')).write_text(p.stdout)
    (evidence / (label + '.status')).write_text(str(p.returncode)+'\n')
    assert p.returncode == expected, (argv, p.returncode, p.stdout)
    return p.stdout.strip()

if mode == 'build':
    pkg, ninja, module, bash, csource, cxxsource = sys.argv[3:9]
    sys.path.insert(0, module)
    import ninja_syntax
    values = {k: os.environ[k] for k in ('PKG_CONFIG', 'PKG_CONFIG_PATH', 'PKG_CONFIG_LIBDIR', 'PKG_CONFIG_SYSROOT_DIR', 'CC', 'CXX', 'NIX_CFLAGS_COMPILE', 'NIX_LDFLAGS')}
    assert values['PKG_CONFIG'] == pkg and values['PKG_CONFIG_PATH'] == values['PKG_CONFIG_SYSROOT_DIR'] == ''
    (evidence / 'environment.json').write_text(json.dumps(values, indent=2)+'\n')
    versions = {'gmp': '6.3.0', 'mpfr': '4.2.2', 'mpc': '1.4.1'}
    selected = {}
    for name, version in versions.items():
        assert run('version-'+name, [pkg, '--modversion', name]) == version
        directory = run('directory-'+name, [pkg, '--variable=pcfiledir', name])
        assert directory in values['PKG_CONFIG_LIBDIR'].split(':')
        pc = Path(directory) / (name+'.pc')
        selected[name] = str(pc)
        (evidence / pc.name).write_bytes(pc.read_bytes())
        for flag in ('--print-requires', '--print-requires-private', '--libs', '--static'):
            args = [pkg, flag, name] if flag != '--static' else [pkg, '--static', '--libs', name]
            run(name+'-'+flag[2:], args)
    (evidence / 'selected-pc.json').write_text(json.dumps(selected, indent=2)+'\n')
    run('missing', [pkg, '--exists', 'tvp-nonexistent'], expected=1)
    run('undeclared', [pkg, '--exists', 'zlib'], expected=1)
    empty = dict(os.environ, PKG_CONFIG_LIBDIR='', PKG_CONFIG_PATH='')
    run('empty-library', [pkg, '--exists', 'gmp'], env=empty, expected=1)
    default = dict(os.environ)
    default.pop('PKG_CONFIG_LIBDIR'); default.pop('PKG_CONFIG_PATH')
    assert run('compiled-default', [pkg, '--variable=pc_path', 'pkg-config'], env=default) == ''
    run('no-host-default', [pkg, '--exists', 'gmp'], env=default, expected=1)
    explicit = dict(empty, PKG_CONFIG_PATH=str(Path(selected['gmp']).parent))
    assert run('explicit-module', [pkg, '--modversion', 'gmp'], env=explicit) == '6.3.0'
    # Public tool output supplies all library include/link flags. No shell eval.
    cflags = shlex.split(run('cflags', [pkg, '--cflags', 'mpc']))
    libs = shlex.split(run('libs', [pkg, '--libs', 'mpc', 'mpfr', 'gmp']))
    cxxlibs = shlex.split(run('cxxlibs', [pkg, '--libs', 'gmpxx', 'gmp']))
    Path('consumer.c').write_bytes(Path(csource).read_bytes())
    Path('consumer.cc').write_bytes(Path(cxxsource).read_bytes())
    Path('value.h').write_text('#define VALUE 7\n')
    # Remove the environment's duplicate library flags; discovery is necessary.
    compile_env = dict(os.environ, NIX_CFLAGS_COMPILE='', NIX_LDFLAGS='')
    buffer = io.StringIO()
    w = ninja_syntax.Writer(buffer)
    quote = lambda argv: shlex.join(argv).replace('$', '$$')
    for lang, compiler, source, flags in [('c', values['CC'], 'consumer.c', libs), ('cxx', values['CXX'], 'consumer.cc', cxxlibs)]:
        w.rule(lang, quote([compiler, '-MMD', '-MF', lang+'.o.d', '-c', source, '-o', lang+'.o', *cflags]), depfile=lang+'.o.d', deps='gcc')
        w.build(lang+'.o', lang, source)
        w.rule('link-'+lang, quote([compiler, '-Wl,-t', '-Wl,-Map,'+lang+'.map', lang+'.o', *flags, '-o', lang+'-consumer']))
        w.build(lang+'-consumer', 'link-'+lang, lang+'.o')
    w.rule('owned-shell', 'test -n "$$BASH_VERSION" && test "$$BASH" = '+bash+' && printf "%s\\n" "$$BASH" > shell-proof')
    w.build('shell-proof', 'owned-shell')
    w.rule('fail', 'printf "intentional failure\\n"; exit 23')
    w.build('failure', 'fail')
    w.default(['c-consumer', 'cxx-consumer', 'shell-proof'])
    Path('build.ninja').write_text(buffer.getvalue())
    (evidence / 'build.ninja').write_text(buffer.getvalue())
    run('first-build', [ninja, '-v'], env=compile_env)
    assert Path('shell-proof').read_text().strip() == bash
    assert run('no-op', [ninja, '-v'], env=compile_env) == 'ninja: no work to do.'
    run('deps', [ninja, '-t', 'deps'], env=compile_env)
    # These raw executables need the discovered arithmetic search dirs until
    # the owned output RPATH step finalizes them. Query the exact target loader.
    loader = sys.argv[9]
    search = sys.argv[10]
    for lang, text in [('c', 'C arithmetic'), ('cxx', 'C++ owned')]:
        assert run('before-'+lang, [loader, '--library-path', search, './'+lang+'-consumer']).endswith(text+' 7')
    # A changed size and future timestamp avoid filesystem timestamp races.
    Path('value.h').write_text('#define VALUE 123\n')
    latest = max(Path(p).stat().st_mtime_ns for p in ['c.o', 'cxx.o']) + 2_000_000_000
    os.utime('value.h', ns=(latest, latest))
    rebuilt = run('header-rebuild', [ninja, '-v'], env=compile_env)
    assert '-c consumer.c' in rebuilt and '-c consumer.cc' in rebuilt
    for lang, text in [('c', 'C arithmetic'), ('cxx', 'C++ owned')]:
        assert run('after-'+lang, [loader, '--library-path', search, './'+lang+'-consumer']).endswith(text+' 123')
    # Return to a normal timestamp before verifying the final no-op.
    os.utime('value.h', ns=(1_000_000_000, 1_000_000_000))
    assert run('no-op-after-header', [ninja, '-v'], env=compile_env) == 'ninja: no work to do.'
    run('failure', [ninja, '-v', 'failure'], env=compile_env, expected=23)
    run('commands', [ninja, '-t', 'commands'], env=compile_env)
    for p in ['c.map', 'cxx.map', 'shell-proof']:
        (evidence / p).write_bytes(Path(p).read_bytes())
