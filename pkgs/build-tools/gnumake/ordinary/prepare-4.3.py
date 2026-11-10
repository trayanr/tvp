"""Bind Make's build shell and reserve a final-only runtime shell slot."""
from pathlib import Path
import os
import sys
shell = sys.argv[1].encode()
root = Path.cwd().resolve()
paths = [Path('src/job.c'), Path('tests/run_make_tests.pl')]
for p in paths:
    assert not p.is_symlink() and p.resolve(strict=True).is_relative_to(root), p
    assert p.stat().st_nlink == 1, p
job, harness = paths
old = b'const char *default_shell = "/bin/sh";'
data = job.read_bytes()
assert data.count(old) == 2
new = b'const char *default_shell = "' + shell + b'\\0TVP_ORDINARY_SHELL_' + b'X' * 238 + b'";'
jobdata = data.replace(old,new)
data = harness.read_bytes()
old = b"$sh_name = '/bin/sh';"
assert data.count(old)==1
data=data.replace(old,b"$sh_name = '"+shell+b"';")
for p, data in [(job, jobdata), (harness, data)]:
    st=p.stat()
    p.write_bytes(data)
    os.utime(p,ns=(st.st_atime_ns,st.st_mtime_ns))
