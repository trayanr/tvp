"""Shared confined-tree validation and staged writes, without package/test policy."""
import os
from pathlib import Path
import stat


def source_files(root):
    if not root.is_absolute() or root.is_symlink() or root.resolve(strict=True) != root:
        raise ValueError("canonical source root required")
    for parent in [root, *root.parents]:
        if not stat.S_ISDIR(parent.lstat().st_mode):
            raise ValueError(("aliased source parent", parent))
    files = []
    for directory, dirs, names in os.walk(root, followlinks=False):
        for name in sorted(dirs + names):
            path = Path(directory) / name
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode):
                if (os.path.isabs(os.readlink(path))
                        or not path.resolve(strict=True).is_relative_to(root)
                        or path.is_dir()):
                    raise ValueError(("unsafe source symlink", path))
            elif stat.S_ISREG(info.st_mode):
                if info.st_nlink != 1:
                    raise ValueError(("source hardlink", path))
                files.append(path)
            elif not stat.S_ISDIR(info.st_mode):
                raise ValueError(("special source file", path))
    return files


def text(path):
    data = path.read_bytes()
    if b"\0" in data:
        raise ValueError(("NUL in source text", path))
    data.decode("utf-8", errors="strict")
    return data


def stage(changes):
    # Validate every destination/collision before opening the first temporary.
    for path in changes:
        if os.path.lexists(str(path) + ".tvp-prepare"):
            raise ValueError(("preparation collision", path))
    for path, data in changes.items():
        info = path.stat()
        temp = Path(str(path) + ".tvp-prepare")
        with temp.open("xb") as stream:
            stream.write(data)
        os.chmod(temp, stat.S_IMODE(info.st_mode))
        os.utime(temp, ns=(info.st_atime_ns, info.st_mtime_ns))
    for path in changes:
        os.replace(str(path) + ".tvp-prepare", path)
