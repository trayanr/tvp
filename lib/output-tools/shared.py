"""New operations reuse the stable selection utilities without changing their source."""

import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

# A separate, explicit Nix source reference preserves existing helper identities.
sys.path.insert(0, sys.argv[3])
from common import files, invocation, selected, tool  # noqa: E402


def selectors(config):
    paths = config["paths"]
    if not isinstance(paths, list) or not paths or not all(isinstance(p, str) for p in paths):
        raise ValueError("paths must be a nonempty list of output selectors")
    return paths


def executable(value):
    if (not isinstance(value, str) or not value.startswith("/")
            or any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in value)
            or any(p in ("", ".", "..") for p in value.split("/")[1:])):
        raise ValueError(f"expected canonical absolute executable path: {value!r}")
    path = Path(value)
    if not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError(f"expected executable file: {path}")
    return value


def restore(path, info):
    os.chmod(path, stat.S_IMODE(info.st_mode))
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))


def replace_contents(path, contents):
    # Never rename over the installed inode: every hardlink keeps the new bytes.
    mode = stat.S_IMODE(path.stat().st_mode)
    try:
        os.chmod(path, mode | stat.S_IWUSR)
        with path.open("r+b") as stream:
            stream.write(contents)
            stream.truncate()
    finally:
        os.chmod(path, mode)


def transformed(path, operation):
    # Tools may rename their output. Stage both checked operations before touching
    # the installed inode, including when strip succeeds but ranlib fails.
    with tempfile.TemporaryDirectory(prefix="strip-archive-") as directory:
        staged = Path(directory) / "library.a"
        shutil.copyfile(path, staged)
        operation(staged)
        replace_contents(path, staged.read_bytes())
