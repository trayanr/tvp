"""Relocate installed PHP prefixes, including compiled CLI/CGI path constants.

PHP embeds its prefix in ELF strings as well as php-config, phpize, headers,
manuals and phar launchers. The recipe selects equal-width A/F store names.
"""
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
old = os.environ['TVP_ARTIFACT_ROOT'].encode()
new = str(root).encode()
if len(old) != len(new):
    raise ValueError('PHP compiled prefix relocation requires equal-width store names')
for path in sorted(root.rglob('*')):
    if path.is_symlink():
        target = os.readlink(path)
        if old.decode() in target:
            path.unlink()
            path.symlink_to(target.replace(old.decode(), new.decode()))
    elif path.is_file():
        data = path.read_bytes()
        if old in data:
            times = path.stat()
            path.write_bytes(data.replace(old, new))
            os.utime(path, ns=(times.st_atime_ns, times.st_mtime_ns))
