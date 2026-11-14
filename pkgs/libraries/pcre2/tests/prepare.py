"""Bind the four upstream PCRE2 grep callouts in a private test tree."""
import os
from pathlib import Path
import stat
import sys

path = Path("RunGrepTest")
info = path.lstat()
if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
    raise ValueError("RunGrepTest must be an independent regular file")
echo = os.fsencode(sys.argv[1])
if not echo.startswith(b"/") or any(c in echo for c in (b"\0", b"\n", b"\r")):
    raise ValueError("expected an absolute selected echo command")
data = path.read_bytes()
if b"\0" in data or data.count(b"/bin/echo|") != 4:
    raise ValueError("unexpected source-bound echo callouts")
replacement = data.replace(b"/bin/echo|", echo + b"|")
temporary = path.with_name(path.name + ".tvp-callouts")
with temporary.open("xb") as output:
    output.write(replacement)
os.chmod(temporary, stat.S_IMODE(info.st_mode))
os.utime(temporary, ns=(info.st_atime_ns, info.st_mtime_ns))
os.replace(temporary, path)
