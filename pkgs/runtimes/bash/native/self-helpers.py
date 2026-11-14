"""Bind installed loadable-module makefiles to this Bash, retaining caller install."""
import os
from pathlib import Path
import sys
sys.path.insert(0, sys.argv[2])
from common import selected
root = Path(sys.argv[1])
if root.is_symlink() or not root.is_absolute() or not root.is_dir() or root.resolve(strict=True) != root:
    raise ValueError("expected owned prefix")
p = selected(root, "lib/bash/Makefile.inc")
if not p.is_file(): raise ValueError("expected regular Makefile.inc")
info = p.stat()
if info.st_nlink != 1:
    raise ValueError("unexpected hardlink to Makefile.inc")
s = p.read_text()
if sys.argv[3] not in s: raise ValueError("expected configured install tool")
p.write_text(s.replace(sys.argv[3], "install") + "\nSHELL = " + str(root / "bin/bash") + "\n")
os.utime(p, ns=(info.st_atime_ns, info.st_mtime_ns))
