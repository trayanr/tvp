"""Remove implicit host library searches using validated owned source selectors."""
import os
from pathlib import Path
import re
import sys
sys.path.insert(0, sys.argv[2])
from common import selected
import stat
root = Path(sys.argv[1])
if root.is_symlink() or not root.is_absolute() or not root.is_dir() or root.resolve(strict=True) != root:
    raise ValueError("expected owned source directory")
# Validate every visited component before inspecting any source file.
path = selected(root, "ltmain.sh")
if not stat.S_ISREG(path.lstat().st_mode):
    raise ValueError("expected regular ltmain.sh")
info = path.stat()
if info.st_nlink != 1:
    raise ValueError("unexpected hardlink to ltmain.sh")
data = path.read_bytes()
search = b" ".join(f[2:].encode() for f in os.environ.get("NIX_LDFLAGS", "").split() if f.startswith("-L"))
data, count = re.subn(rb'eval "(sys_lib_search_path=).*', lambda m: m[1] + b"'" + search + b"'", data)
if count != 1: raise ValueError("expected libtool system-search anchor")
data = re.sub(rb'eval "sys_lib_dlsearch_path=.*', b"", data)
path.write_bytes(data)
os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
