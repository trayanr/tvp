"""Bind Gzip's installed helper profile, including gzexe's emitted script."""
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
    for value in [config["shell"], config["buildGrep"], config["grep"], config["pager"], *config["paths"]]:
        if not value.startswith("/") or any(c in value for c in "\0\n\r:"):
            raise ValueError("invalid runtime command/path")
    path = str(directory) + ":" + ":".join(config["paths"])
    preamble = "PATH=" + shlex.quote(path) + ':"${PATH-}"; export PATH\n'
    changes = []
    for name in config["helpers"]:
        if not name or Path(name).name != name or name in {".", ".."}:
            raise ValueError("invalid helper name")
        target = directory / name
        info = target.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError(("unsupported/shared helper", name))
        data = target.read_bytes()
        if b"\0" in data:
            raise ValueError(("NUL in installed helper", name))
        text = data.decode("utf-8")
        if not re.fullmatch(r"#![ \t]*/(?:[^ \t\n]+/)*(?:sh|bash)\n", text.splitlines(keepends=True)[0]):
            raise ValueError(("unsupported helper interpreter", name))
        if name == "gzexe":
            before = "skip=" + str(config["skip"]) + "\n"
            after = "skip=" + str(config["skip"] + 1) + "\n"
            if text.count(before) != 1:
                raise ValueError("unexpected gzexe embedded-script layout")
            text = text.replace(before, after)
        rendered = []
        for line in text.splitlines(keepends=True):
            if line.startswith("#!"):
                rendered.append("#!" + config["shell"] + "\n")
                if len(rendered) == 1:
                    rendered.append(preamble)
            else:
                rendered.append(line)
                if name == "gzexe" and line == after:
                    rendered.append(preamble)
        text = "".join(rendered).replace(config["buildGrep"], config["grep"])
        if name == "zless":
            text = text.replace("exec less ", "SHELL=" + shlex.quote(config["shell"]) + "; export SHELL\nexec less ")
        if name == "zmore":
            if text.count("${PAGER-more}") != 1:
                raise ValueError("unexpected zmore pager default")
            text = text.replace("${PAGER-more}", "${PAGER-" + config["pager"] + "}")
        temporary = target.with_name(target.name + ".tvp-binding")
        if os.path.lexists(temporary):
            raise ValueError(("helper binding collision", name))
        changes.append((target, temporary, text.encode(), info))
    # Validate all helpers and collisions before staging; commit only after every
    # replacement has been written successfully. Source helpers remain untouched.
    for target, temporary, data, info in changes:
        with temporary.open("xb") as stream:
            stream.write(data)
        os.chmod(temporary, stat.S_IMODE(info.st_mode))
        os.utime(temporary, ns=(info.st_atime_ns, info.st_mtime_ns))
    for target, temporary, data, info in changes:
        os.replace(temporary, target)


if __name__ == "__main__":
    bind(Path(sys.argv[1]), json.loads(sys.argv[2]))
