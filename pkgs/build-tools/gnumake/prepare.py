"""Reserve Make's native default-shell C-string slot, without touching tests.

This new ordinary helper is deliberately separate from owned/prepare.py, whose
bytes are pinned by bootstrap/gnu-tool-floor and must remain unchanged.
"""
from pathlib import Path
import os
import stat
import sys

shell = os.fsencode(sys.argv[1])
if not shell.startswith(b"/nix/store/") or any(c in shell for c in (b'"', b"\\", b"\0", b"\n")):
    raise ValueError("expected literal declared shell path")
root = Path.cwd()
if root.resolve(strict=True) != root or root.is_symlink():
    raise ValueError("expected private canonical source root")
path = root / "src/job.c"
for parent in (root / "src", path):
    info = parent.lstat()
    if parent.is_symlink():
        raise ValueError(f"source alias: {parent}")
    if parent == path and (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1):
        raise ValueError("expected singly linked job source")
info = path.stat()
data = path.read_bytes()
old = b'const char *default_shell = "/bin/sh";'
if data.count(old) != 2:
    raise ValueError("unexpected GNU Make native/OS2 shell declarations")
replacement = b'const char *default_shell = "' + shell + b'\\0TVP_ORDINARY_SHELL_' + b'X' * 238 + b'";'
path.write_bytes(data.replace(old, replacement))
os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
