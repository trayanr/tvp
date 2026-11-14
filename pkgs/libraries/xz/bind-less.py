"""Bind the installed xzless pager, preserving the upstream LESSOPEN contract."""
import os
from pathlib import Path
import shlex
import sys
def text(path):
    data = path.read_bytes()
    if b"\0" in data:
        raise ValueError("NUL in helper")
    data.decode("utf-8", errors="strict")
    return data

root = Path(sys.argv[1])
if not root.is_absolute() or root.resolve(strict=True) != root:
    raise ValueError('canonical output required')
for p in [root/'bin', root, *root.parents]:
    if p.is_symlink() or not p.is_dir():
        raise ValueError(('invalid parent', p))
p = root/'bin/xzless'
if p.is_symlink() or not p.is_file() or p.stat().st_nlink != 1:
    raise ValueError('independent xzless required')
data = text(p)
if not data.startswith(b'#!/nix/store/') or data.split(b'\n')[0].split(b'/')[-1] != b'bash':
    raise ValueError('selected shell frontend required')
pager = sys.argv[2]
if not os.path.isabs(pager) or '\n' in pager or '\0' in pager:
    raise ValueError('absolute pager required')
if data.count(b'$(less -V') != 1 or data.count(b'exec less "$@"') != 1:
    raise ValueError('unsupported pager anchors')
selected = shlex.quote(pager).encode()
data = data.replace(b'$(less -V', b'$(' + selected + b' -V').replace(b'exec less "$@"', b'exec ' + selected + b' "$@"')
# Validation is complete before opening the destination.
p.write_bytes(data)
