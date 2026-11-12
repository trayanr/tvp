"""Rebase CPython's installed prefix, including getpath, libpython and pyc paths.

Only the installed tree is transported. Equal-width prefixes preserve compiled
string/marshal lengths and archive offsets; production and tests stay separate.
"""
import os
from pathlib import Path
import stat
import sys


def relocate(root, old):
    new = os.fsencode(root)
    if not old or old == new or len(old) != len(new):
        raise ValueError('CPython requires distinct equal-width installed prefixes')
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise ValueError('expected an owned installed directory')
    if any(p.is_symlink() for p in root.parents):
        raise ValueError('symlink root component')
    files, links, counts = [], [], {}
    for current, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            path = Path(current, name)
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode):
                links.append(path)
            elif stat.S_ISREG(info.st_mode):
                files.append((path, info))
                key = (info.st_dev, info.st_ino)
                counts[key] = counts.get(key, 0) + 1
            elif not stat.S_ISDIR(info.st_mode):
                raise ValueError('special installed file: ' + str(path))
    if any(counts[(i.st_dev, i.st_ino)] != i.st_nlink for _, i in files):
        raise ValueError('external installed hardlink')
    # Validate all inputs before any write. write_bytes preserves internal inodes.
    for path, info in files:
        data = path.read_bytes()
        if old in data:
            mode = stat.S_IMODE(info.st_mode)
            try:
                path.chmod(mode | stat.S_IWUSR)
                path.write_bytes(data.replace(old, new))
            finally:
                path.chmod(mode)
                os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
    for path in links:
        target = os.fsencode(os.readlink(path))
        if old in target:
            path.unlink()
            path.symlink_to(os.fsdecode(target.replace(old, new)))
    for path, _ in files:
        if old in path.read_bytes():
            raise ValueError('remaining artifact prefix: ' + str(path))


if __name__ == '__main__':
    relocate(Path(sys.argv[1]), os.fsencode(os.environ['TVP_ARTIFACT_ROOT']))
