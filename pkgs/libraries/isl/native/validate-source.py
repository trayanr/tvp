"""CPython's explicit prefix/shell adaptations; validate ownership before writes."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

root = Path(sys.argv[1])
config = json.loads(sys.argv[2])
action = sys.argv[3]
if not root.is_absolute() or root.is_symlink() or not root.is_dir():
    raise ValueError("expected owned directory")
if any(part in ("", ".", "..") for part in str(root).split("/")[1:]):
    raise ValueError("unsafe root components")
for parent in root.parents:
    if parent.is_symlink():
        raise ValueError("symlink root component")
# Validate all components and link counts before the first mutation. Symlinks
# are never traversed; internal output aliases are retained as installed.
files = []
def walk(directory):
    for path in sorted(directory.iterdir()):
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            if action in ('validate-source', 'prepare'):
                raise ValueError(f"source symlink: {path}")
            continue
        if stat.S_ISDIR(info.st_mode):
            walk(path)
        elif stat.S_ISREG(info.st_mode):
            files.append((path, info))
        else:
            raise ValueError(f"special file: {path}")
walk(root)
counts = {}
for p, i in files:
    key = (i.st_dev, i.st_ino)
    counts[key] = counts.get(key, 0) + 1
for p, i in files:
    if counts[(i.st_dev, i.st_ino)] != i.st_nlink:
        raise ValueError(f"external hardlink: {p}")
owned = {p.relative_to(root).as_posix(): (p, i) for p, i in files}
if action != 'validate-source':
    raise ValueError(action)
