"""Select Make's native runtime shell and its upstream test shell explicitly."""
from pathlib import Path
import os
import sys

shell = sys.argv[1].encode()
path = Path("src/job.c")
info = path.stat()
data = path.read_bytes()
old = b'const char *default_shell = "/bin/sh";'
# One native branch and one OS/2 branch share this literal in this archive.
if data.count(old) != 2:
    raise ValueError("unexpected Make 4.4.1 default-shell source")
path.write_bytes(data.replace(old, b'const char *default_shell = "' + shell + b'\\0TVP_ORDINARY_SHELL_' + b'X' * 238 + b'";'))
os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
