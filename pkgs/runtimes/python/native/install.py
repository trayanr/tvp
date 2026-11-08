"""Retain complete payload with explicit installed interpreter/helper bindings."""
from pathlib import Path
import os
import sys
root, shell, helper_path = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
for p in root.rglob('*'):
    if not p.is_file() or p.is_symlink():
        continue
    st = p.stat()
    if p.suffix == '.py' or p.parent == root / 'bin':
        data = p.read_bytes()
        if data.startswith(b'#!') and b'python' in data.split(b'\n', 1)[0]:
            p.write_bytes(b'#!' + str(root).encode() + b'/bin/python3\n' + data.split(b'\n', 1)[1])
    if p.name in ['install-sh', 'makesetup'] and p.parent.name.startswith('config-'):
        text = p.read_text().split('\n', 1)[1]
        p.write_text('#!' + shell + '\nexport PATH=' + helper_path + '\n' + text)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))

# Installation has already generated checked-hash bytecode. Rebind only caches
# whose source shebang changed, using this build's installed target interpreter.
# The 3.12 preparation helper must not generate 3.15 bytecode.
import json
import subprocess
changed = []
for p in root.rglob('*.py'):
    if p.read_bytes().startswith(b'#!' + str(root).encode() + b'/bin/python3\n'):
        for cache in (p.parent / '__pycache__').glob(p.stem + '.*.pyc'):
            optimize = 2 if '.opt-2.' in cache.name else 1 if '.opt-1.' in cache.name else 0
            changed.append((str(p), str(cache), optimize))
subprocess.run([str(root / 'bin/python3'), '-I', '-c', '''
import json, py_compile, sys
for source, cache, optimize in json.loads(sys.argv[1]):
    py_compile.compile(source, cfile=cache, doraise=True, optimize=optimize,
                       invalidation_mode=py_compile.PycInvalidationMode.CHECKED_HASH)
''', json.dumps(changed)], check=True)
