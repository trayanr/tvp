"""Retain complete payload with explicit installed interpreter/helper bindings."""
from pathlib import Path
import os
import sys
root, shell, helper_path = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
source_shell = sys.argv[4] if len(sys.argv) > 4 else shell
runtime_shell = sys.argv[5] if len(sys.argv) > 5 else shell
for p in root.rglob('*'):
    if not p.is_file() or p.is_symlink():
        continue
    st = p.stat()
    if p.name == 'subprocess.py' and p.parent.name.startswith('python'):
        data = p.read_text()
        assert source_shell in data, p
        p.write_text(data.replace(source_shell, runtime_shell))
    if p.suffix == '.py' or p.parent == root / 'bin':
        data = p.read_bytes()
        if data.startswith(b'#!') and b'python' in data.split(b'\n', 1)[0]:
            p.write_bytes(b'#!' + str(root).encode() + b'/bin/python3\n' + data.split(b'\n', 1)[1])
    if p.parent == root / 'bin':
        data = p.read_bytes()
        if data.startswith(b'#!' + source_shell.encode() + b'\n'):
            p.write_bytes(b'#!' + runtime_shell.encode() + b'\n' + data.split(b'\n', 1)[1])
    if p.name in ['install-sh', 'makesetup'] and p.parent.name.startswith('config-'):
        text = p.read_text().split('\n', 1)[1]
        if text.startswith('export PATH='):
            text = text.split('\n', 1)[1]
        p.write_text('#!' + shell + '\nexport PATH=' + helper_path + '\n' + text)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))

# Recompile only caches installed by upstream, using the target interpreter.
# This repairs changed source hashes and avoids using construction Python's ABI.
import json
import subprocess
caches = []
for p in root.rglob('*.py'):
    for cache in (p.parent / '__pycache__').glob(p.stem + '.*.pyc'):
        optimize = 2 if '.opt-2.' in cache.name else 1 if '.opt-1.' in cache.name else 0
        caches.append((str(p), str(cache), optimize))
subprocess.run([str(root / 'bin/python3'), '-I', '-c', '''
import json, py_compile, sys
options = {}
if sys.version_info >= (3, 7):
    options['invalidation_mode'] = py_compile.PycInvalidationMode.CHECKED_HASH
for source, cache, optimize in json.load(sys.stdin):
    py_compile.compile(source, cfile=cache, doraise=True, optimize=optimize, **options)
'''], input=json.dumps(caches).encode(), check=True)
