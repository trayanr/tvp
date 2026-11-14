"""Retain Bzip2's declared-tools and caller-tools installed helper contracts."""
import json
import os
from pathlib import Path
import re
import shlex
import stat
import sys


def bind(root, config):
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise ValueError("invalid installed root")
    directory = root / "bin"
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("invalid installed bin directory")
    for value in [config["shell"], config["pager"], *config["paths"]]:
        if not value.startswith("/") or any(c in value for c in "\0\n\r:"):
            raise ValueError("invalid runtime command/path")
    preamble = ""
    if config["declared"]:
        preamble = ("PATH=" + shlex.quote(str(directory) + ":" + ":".join(config["paths"]))
                    + ':"${PATH-}"\nexport PATH\nSHELL=' + shlex.quote(config["shell"]) + "\nexport SHELL\n")
    changes = []
    for name in ["bzgrep", "bzmore", "bzdiff"]:
        target = directory / name
        info = target.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError(("unsupported/shared helper", name))
        data = target.read_bytes()
        if b"\0" in data or b"\n" not in data:
            raise ValueError(("malformed shell helper", name))
        first, body = data.split(b"\n", 1)
        if not re.fullmatch(rb"#![ \t]*/(?:[^ \t\n]+/)*(?:sh|bash)", first):
            raise ValueError(("unexpected helper interpreter", name))
        if name == "bzdiff":
            if body.count(b"/bin/rm -f") != 1:
                raise ValueError("unexpected bzdiff cleanup command")
            body = body.replace(b"/bin/rm -f", b"rm -f")
        if name == "bzmore" and config["declared"]:
            body = body.replace(b"${PAGER:-more}", b"${PAGER:-" + config["pager"].encode() + b"}")
            body = body.replace(b"${PAGER-more}", b"${PAGER-" + config["pager"].encode() + b"}")
        replacement = b"#!" + config["shell"].encode() + b"\n" + preamble.encode() + body
        temporary = target.with_name(target.name + ".tvp-binding")
        if os.path.lexists(temporary):
            raise ValueError(("helper binding collision", name))
        changes.append((target, temporary, replacement, info))
    for target, temporary, data, info in changes:
        with temporary.open("xb") as stream:
            stream.write(data)
        os.chmod(temporary, stat.S_IMODE(info.st_mode))
        os.utime(temporary, ns=(info.st_atime_ns, info.st_mtime_ns))
    for target, temporary, data, info in changes:
        os.replace(temporary, target)


if __name__ == "__main__":
    bind(Path(sys.argv[1]), json.loads(sys.argv[2]))
