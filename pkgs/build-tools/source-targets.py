"""Validate explicit prepared-source text targets before opening or patching them."""
from pathlib import Path
import stat
import sys


def text_file(relative, root=None):
    root = Path.cwd() if root is None else Path(root)
    if (not root.is_absolute() or root != root.resolve(strict=True)
            or not stat.S_ISDIR(root.lstat().st_mode)):
        raise ValueError("expected a canonical source directory")
    if (not isinstance(relative, str) or "\0" in relative
            or any(part in ("", ".", "..") for part in relative.split("/"))):
        raise ValueError("expected an explicit relative source path")
    parts = relative.split("/")
    path = root
    for part in parts[:-1]:
        path = path / part
        if not stat.S_ISDIR(path.lstat().st_mode):
            raise ValueError("source parent must be a real directory")
    path = path / parts[-1]
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError("source target must be a regular singly linked file")
    text = path.read_text(encoding="utf-8")
    if "\0" in text:
        raise ValueError("source text contains NUL")
    return path, text


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise ValueError("expected explicit source targets")
    for target in sys.argv[1:]:
        text_file(target)
