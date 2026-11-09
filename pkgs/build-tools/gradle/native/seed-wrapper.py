#!@python@
"""Seed the exact verified all.zip; upstream Wrapper verifies and installs it."""
import hashlib
import os
import stat
from pathlib import Path

version = "@version@"
filename = f"gradle-{version}-all.zip"
url = f"https://services.gradle.org/distributions/{filename}"
value = int.from_bytes(hashlib.md5(url.encode()).digest(), "big")
encoded = ""
while value:
    value, digit = divmod(value, 36)
    encoded = "0123456789abcdefghijklmnopqrstuvwxyz"[digit] + encoded
home = Path(os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle")))
cache = home / "wrapper" / "dists" / filename.removesuffix(".zip") / encoded
# Use no-follow directory descriptors; never overwrite an existing cache inode.
fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
try:
    for part in cache.absolute().parts[1:]:
        if part in ('', '.', '..'):
            raise ValueError('unsafe cache component')
        try:
            os.mkdir(part, mode=0o755, dir_fd=fd)
        except FileExistsError:
            pass
        next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
        os.close(fd)
        fd = next_fd
    if os.fstat(fd).st_uid != os.getuid():
        raise ValueError('cache is not owned by current user')
    try:
        marker = os.stat(filename + '.ok', dir_fd=fd, follow_symlinks=False)
    except FileNotFoundError:
        marker = None
    if marker is not None:
        if not stat.S_ISREG(marker.st_mode) or marker.st_nlink != 1 or marker.st_uid != os.getuid():
            raise ValueError('unsafe wrapper marker')
    else:
        try:
            os.symlink('@archive@', filename, dir_fd=fd)
        except FileExistsError:
            pass
finally:
    os.close(fd)
