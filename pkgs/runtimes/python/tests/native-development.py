"""Build/load extensions and static embeddings from three installed APIs."""
from pathlib import Path
import importlib
import os
import shlex
import subprocess
import sys
import sysconfig
answer, embed = sys.argv[1:]
sys.path.insert(0, str(Path.cwd()))

def output(*args):
    return subprocess.check_output(args, text=True).strip()

def run(args):
    print(shlex.join(args), file=sys.stderr)
    subprocess.run(args, check=True)

assert sysconfig.get_config_var('CC').startswith('/nix/store/')
cc = shlex.split(sysconfig.get_config_var('CC'))
suffix = sysconfig.get_config_var('EXT_SUFFIX')
# Installed sysconfig compiler and includes; load the resulting extension.
run(shlex.split(sysconfig.get_config_var('LDSHARED')) + ['-fPIC', '-I'+sysconfig.get_path('include'), answer, '-o', 'answer'+suffix])
assert importlib.import_module('answer').answer()==42
Path('answer'+suffix).unlink()
# pkg-config's public extension and static embed recipes, independently.
os.environ['PKG_CONFIG_LIBDIR'] = sys.prefix+'/lib/pkgconfig'
for mode, source, flags, target in [
    ('module', answer, ['--cflags','python-3.15'], 'answer'+suffix),
    ('embed', embed, ['--cflags','--libs','python-3.15-embed'], 'embed-pc')]:
    extra = ['-shared','-fPIC'] if mode=='module' else []
    run(cc+extra+[source]+shlex.split(output('pkg-config',*flags))+['-o',target])
    if mode=='module':
        run([sys.executable,'-c','import answer; assert answer.answer()==42'])
    else:
        assert output('./'+target)=='42'
assert output('python3-config','--prefix')==sys.prefix
assert sys.prefix in output('python3-config','--includes')
assert '-lpython3.15' in output('python3-config','--embed','--ldflags')
print('interfaces')
