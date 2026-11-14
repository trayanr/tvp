"""Bind generated configure's public version and API layout before configuration."""
import os
from pathlib import Path
import re
import stat
import sys

version, api = sys.argv[1:]
if not re.fullmatch(r'[0-9]+(?:\.[0-9]+)+', version) or not re.fullmatch(r'[0-9]+\.[0-9]+', api):
    raise ValueError('expected numeric release/API version')
p = Path('configure')
info = p.lstat()
if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
    raise ValueError('configure must be an independent regular file')
temporary = p.with_name(p.name + '.tvp-api-preparing')
if temporary.exists() or temporary.is_symlink():
    raise ValueError('configure preparation temporary already exists')
data = p.read_text()
patterns = [
    (r"(?m)^PACKAGE_VERSION='[^']+'$", "PACKAGE_VERSION='" + version + "'", 1),
    (r"(?m)^PACKAGE_STRING='[^']+'$", "PACKAGE_STRING='automake " + version + "'", 1),
]
# Count exact assignments, including the older echo/sed spelling. Do not touch
# config.status's later APIVERSION=$APIVERSION serialization.
patterns += [
    (r"(?m)^ VERSION='[^']+'$", " VERSION='" + version + "'", 1),
    (r"(?m)^am__api_version='[0-9.]+'$", "am__api_version='" + api + "'", 1),
    (r'(?m)^APIVERSION=(?:`echo[^\n]+`|[0-9.]+)$', "APIVERSION='" + api + "'", 1),
]
for pattern, replacement, expected in patterns:
    data, count = re.subn(pattern, lambda m: replacement, data)
    if count != expected:
        raise ValueError((pattern, count, expected))
fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
try:
    with os.fdopen(fd, 'w') as stream:
        stream.write(data)
    temporary.chmod(stat.S_IMODE(info.st_mode))
    os.utime(temporary, ns=(info.st_atime_ns, info.st_mtime_ns))
    temporary.replace(p)
finally:
    if temporary.exists():
        temporary.unlink()
