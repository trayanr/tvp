"""Audit symlinks below explicit output directories without traversing them."""
import os
from pathlib import Path
import stat
import sys

sys.path.insert(0, sys.argv[3])
from common import invocation, selected

root, config = invocation()
selectors = config["paths"]
if not isinstance(selectors, list) or not selectors:
    raise ValueError("expected explicit output directories")

directories = [selected(root, selector) for selector in selectors]
for directory in directories:
    if not stat.S_ISDIR(directory.lstat().st_mode):
        raise ValueError(f"expected output directory: {directory}")


def check_link(path):
    # Resolve one component at a time: an otherwise relative link can hide an
    # absolute or escaping link outside the selected subtree. Never leave root.
    pending = list(path.relative_to(root).parts)
    current = root
    followed = 0
    while pending:
        part = pending.pop(0)
        if part in ("", "."):
            continue
        if part == "..":
            if current == root:
                raise ValueError(f"output symlink escapes root: {path}")
            current = current.parent
            continue
        current = current / part
        info = current.lstat()  # Dangling targets fail rather than disappearing.
        if stat.S_ISLNK(info.st_mode):
            target = Path(os.readlink(current))
            if target.is_absolute():
                raise ValueError(f"expected relative output symlink: {current}")
            followed += 1
            # Match the Linux path-resolution limit and bound cyclic chains.
            if followed > 40:
                raise ValueError(f"cyclic or excessive output symlink chain: {path}")
            pending = list(target.parts) + pending
            current = current.parent
        elif pending and not stat.S_ISDIR(info.st_mode):
            raise ValueError(f"non-directory output symlink component: {current}")


def walk(directory):
    for path in sorted(directory.iterdir()):
        mode = path.lstat().st_mode
        if stat.S_ISLNK(mode):
            check_link(path)
        elif stat.S_ISDIR(mode):
            walk(path)
        elif not stat.S_ISREG(mode):
            raise ValueError(f"unsupported output file: {path}")


for directory in directories:
    walk(directory)
