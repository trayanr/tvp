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
