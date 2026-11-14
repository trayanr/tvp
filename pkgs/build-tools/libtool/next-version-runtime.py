"""Restore the declared runtime PATH for Libtool's optional next-version frontend."""
import os
from pathlib import Path
import shlex
import stat
import sys
import tempfile


def bind(root, runtime_path):
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise ValueError("invalid installed root")
    directory = root / "bin"
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("invalid frontend directory")
    path = directory / "libtool-next-version"
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError("unsupported/shared next-version frontend")
    data = path.read_bytes()
    if b"\0" in data or not data.startswith(b"#!") or b"\n" not in data:
        raise ValueError("invalid next-version frontend")
    if any(not part.startswith("/nix/store/") or any(c in part for c in "\n\r\0")
           for part in runtime_path.split(":")):
        raise ValueError("invalid runtime PATH")
    first, body = data.split(b"\n", 1)
    preamble = ("PATH=" + shlex.quote(runtime_path) + ':"${PATH-}"\nexport PATH\n').encode()
    replacement = first + b"\n" + preamble + body
    fd, temporary = tempfile.mkstemp(prefix=".libtool-next-version.", dir=directory)
    try:
        with os.fdopen(fd, "wb") as target:
            target.write(replacement)
        os.chmod(temporary, stat.S_IMODE(info.st_mode))
        os.utime(temporary, ns=(info.st_atime_ns, info.st_mtime_ns))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    bind(Path(sys.argv[1]), sys.argv[2])
