"""Only owned regular native ELF files; validate components before any I/O."""
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[2])
from common import files, elf, tool
root = Path(sys.argv[1])
if root.is_symlink() or not root.is_absolute() or not root.is_dir():
    raise ValueError("expected owned prefix")
for path in files(root, ["bin", "lib"]):
    if elf(path, sys.argv[3]) is not None:
        tool(sys.argv[4], "--add-rpath", str(root / "lib"), path)
