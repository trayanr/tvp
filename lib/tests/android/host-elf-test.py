"""Bounded helper controls with exact exit and confinement assertions."""
import hashlib
import json
from pathlib import Path
import os
import shutil
import subprocess
import sys

helper, common, binary, readelf, patchelf = sys.argv[1:6]
config = json.loads(sys.argv[6]) | {'readelf': readelf, 'patchelf': patchelf, 'paths': ['bin'], 'patterns': []}
base = Path.cwd() / 'host-controls'
base.mkdir()

def fixture(name):
    root = base / name
    (root / 'bin').mkdir(parents=True)
    (root / 'lib').mkdir()
    path = root / 'bin/tool'
    shutil.copyfile(binary, path)
    path.chmod(0o755)
    subprocess.run([patchelf, '--set-rpath', '$ORIGIN/../lib', path], check=True)
    return root, path

def run(root, expected, changes=None):
    c = config | (changes or {})
    result = subprocess.run([sys.executable, '-B', helper, str(root), json.dumps(c), common], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert (result.returncode == 0) == expected, result.stderr.decode()
    print(root.name, result.returncode, file=sys.stderr)
    return result

root, path = fixture('positive')
run(root, True)
rpath = subprocess.check_output([patchelf, '--print-rpath', path]).decode().strip()
assert rpath.split(':')[0] == '$ORIGIN/../lib'
assert subprocess.check_output([path]) == b''
assert subprocess.check_output([patchelf, '--print-interpreter', path]).decode().strip() == config['loader']
for case in [
    'parent-symlink', 'hardlink', 'target-elf', 'unsupported-rpath',
    'bad-selector', 'special-file', 'missing-pattern', 'typo-pattern',
]:
    root, path = fixture(case)
    external = base / (case + '-external')
    external.mkdir()
    (external / 'sentinel').write_text('outside')
    changes = {}
    deeper = None
    if case == 'parent-symlink':
        (root / 'escape').symlink_to(external, target_is_directory=True)
        changes['paths'] = ['bin', 'escape/sentinel']
    elif case == 'hardlink':
        os.link(path, external / 'linked')
    elif case == 'target-elf':
        data = bytearray(path.read_bytes()); data[18:20] = (183).to_bytes(2, 'little')
        (root / 'bin/zz-target').write_bytes(data)
    elif case == 'unsupported-rpath':
        subprocess.run([patchelf, '--set-rpath', '/outside/lib', path], check=True)
    elif case == 'bad-selector':
        changes['paths'] = ['bin', '../outside']
    elif case == 'special-file':
        os.mkfifo(root / 'bin/zz-fifo')
    elif case == 'missing-pattern':
        changes['patterns'] = ['python/lib/python*/lib-dynload']
    elif case == 'typo-pattern':
        deeper = root / 'python/lib/python3.13/lib-dynload/module.so'
        deeper.parent.mkdir(parents=True)
        shutil.copyfile(path, deeper)
        subprocess.run([patchelf, '--set-rpath', '/outside/lib', deeper], check=True)
        changes['patterns'] = ['python/lib/python*/lib-dynloads']
    before = hashlib.sha256(path.read_bytes()).hexdigest()
    deeper_before = hashlib.sha256(deeper.read_bytes()).hexdigest() if deeper else None
    outside = {p.name: p.read_bytes() for p in external.iterdir()}
    result = run(root, False, changes)
    if case in ['missing-pattern', 'typo-pattern']:
        assert b'required host pattern matched no directories:' in result.stderr
    assert hashlib.sha256(path.read_bytes()).hexdigest() == before
    if deeper:
        assert hashlib.sha256(deeper.read_bytes()).hexdigest() == deeper_before
    assert {p.name: p.read_bytes() for p in external.iterdir()} == outside
