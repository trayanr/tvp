"""Only owned regular native ELF files; validate components before any I/O."""
from collections import Counter
import os
from pathlib import Path
import stat
import sys
sys.path.insert(0, sys.argv[2])
from common import files, elf, tool
root = Path(sys.argv[1])
if root.is_symlink() or not root.is_absolute() or not root.is_dir() or root.resolve(strict=True) != root:
    raise ValueError("expected owned prefix")

def fail(error):
    raise error

# Count every owned alias, including aliases outside the selected directories.
# Preflight all selected inodes before reading or modifying the first ELF.
paths = list(files(root, ["bin", "lib"]))
aliases = Counter()
for directory, _, names in os.walk(root, followlinks=False, onerror=fail):
    for name in names:
        info = (Path(directory) / name).lstat()
        if stat.S_ISREG(info.st_mode):
            aliases[(info.st_dev, info.st_ino)] += 1
for path in paths:
    info = path.lstat()
    if aliases[(info.st_dev, info.st_ino)] != info.st_nlink:
        raise ValueError(f"hardlink outside owned prefix: {path}")

for path in paths:
    if elf(path, sys.argv[3]) is not None:
        tool(sys.argv[4], "--add-rpath", str(root / "lib"), path)
