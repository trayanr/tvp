"""Fill the explicitly patched Ninja subprocess shell slots."""
from pathlib import Path
import os
import stat
import sys

shell = os.fsencode(sys.argv[1])
if len(shell) != 256 or not shell.lstrip(b"/").startswith(b"nix/store/"):
    raise ValueError("expected fixed-width declared Ninja shell")
if any(c in shell for c in (b"\0", b"\n", b'"', b"\\")):
    raise ValueError("shell path cannot be represented as a C string")
root = Path.cwd()
if root != root.resolve(strict=True) or root.is_symlink():
    raise ValueError("expected canonical private source root")
path = root / "src/subprocess-posix.cc"
for parent in (root / "src", path):
    info = parent.lstat()
    if parent.is_symlink():
        raise ValueError("source alias in Ninja shell target")
    if parent == path and (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1):
        raise ValueError("expected singly linked source text")
info = path.stat()
data = path.read_bytes()
if b"\0" in data or data.count(b"@TVP_SHELL@") != 2:
    raise ValueError("unexpected Ninja patched shell declarations")
# Validate every requested replacement before the single source write.
data.decode("utf-8")
path.write_bytes(data.replace(b"@TVP_SHELL@", shell))
os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
