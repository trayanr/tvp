"""Prepare the fixed historical GCC source profiles before compilation."""
from pathlib import Path
import os
import re
import stat
import sys


def prepare(root, shell, perl, loader):
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError("GCC source must be a real directory")
    root = root.resolve(strict=True)
    pending = []
    for directory, directories, names in os.walk(root, followlinks=False):
        for name in directories:
            path = Path(directory) / name
            if path.is_symlink():
                raise ValueError(("source directory alias", str(path.relative_to(root))))
        for name in names:
            path = Path(directory) / name
            st = path.lstat()
            if stat.S_ISLNK(st.st_mode):
                if not path.resolve(strict=True).is_relative_to(root):
                    raise ValueError(("escaping source link", str(path.relative_to(root))))
                continue
            if not stat.S_ISREG(st.st_mode):
                raise ValueError(("special source file", str(path.relative_to(root))))
            with path.open("rb") as handle:
                head = handle.read(128).split(b"\n", 1)[0]
            if not head.startswith(b"#!"):
                continue
            words = head[2:].strip().split(None, 1)
            if not words:
                continue
            interpreter = words[0]
            replacement = None
            if interpreter in (b"/bin/sh", b"/bin/bash", b"/usr/bin/sh", b"/usr/bin/bash"):
                replacement = shell.encode()
            elif interpreter in (b"/usr/bin/perl", b"/bin/perl"):
                replacement = perl.encode()
            if replacement is not None:
                data = path.read_bytes()
                if b"\0" in data or st.st_nlink != 1:
                    raise ValueError(("invalid/shared source script", str(path.relative_to(root))))
                pending.append((path, b"#!" + replacement + b"\n" + data.split(b"\n", 1)[1]))
    path = root / "gcc/config/i386/linux64.h"
    if path.is_symlink() or path.stat().st_nlink != 1:
        raise ValueError("shared GCC loader header")
    original = path.read_text()
    updated, count = re.subn(
        r'^(#define GLIBC_DYNAMIC_LINKER(?:32|64|X32) )"[^"]*"',
        lambda match: match[1] + '"' + loader + '"', original, flags=re.M,
    )
    if count != 3:
        raise ValueError(("GCC loader definition count", count))
    pending.append((path, updated.encode()))
    # Validate the complete edit set before changing any source bytes.
    for path, data in pending:
        path.write_bytes(data)


if __name__ == "__main__":
    prepare(*sys.argv[1:])
