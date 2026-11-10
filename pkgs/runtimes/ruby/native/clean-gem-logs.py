"""Drop installation-time gem diagnostics, retaining gem extension sources."""
from pathlib import Path
import sys

sys.path.insert(0, sys.argv[3])
from common import files

root = Path(sys.argv[1])
if not root.is_absolute() or root.is_symlink() or not root.is_dir():
    raise ValueError(f"expected owned output directory: {root}")
root = root.resolve(strict=True)
for path in files(root, [sys.argv[2]]):
    if path.name == 'mkmf.log':
        if path.stat().st_nlink != 1:
            raise ValueError(f"hardlinked build log: {path}")
        path.unlink()
