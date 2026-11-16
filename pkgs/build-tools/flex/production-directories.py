"""Keep Flex's test-only generated parsers out of production make recursion."""
from pathlib import Path
import os
import re
import stat
import sys


def prepare(path):
    mode = path.lstat()
    if not stat.S_ISREG(mode.st_mode) or mode.st_nlink != 1:
        raise ValueError("expected private generated Makefile")
    data = path.read_bytes()
    if b"\0" in data:
        raise ValueError("NUL in generated Makefile")
    text = data.decode("utf-8")
    matches = list(re.finditer(r"(?m)^SUBDIRS[ \t]*=[ \t]*((?:[^\n]*\\\n)*[^\n]*)", text))
    if len(matches) != 1:
        raise ValueError("expected one generated SUBDIRS assignment")
    match = matches[0]
    directories = match[1].replace("\\\n", " ").split()
    if directories.count("tests") != 1 or not all(
        re.fullmatch(r"[A-Za-z0-9_-]+", directory) for directory in directories
    ):
        raise ValueError("unexpected Flex SUBDIRS layout")
    selected = [directory for directory in directories if directory != "tests"]
    if not selected:
        raise ValueError("empty production directory selection")
    result = text[:match.start()] + "SUBDIRS = " + " ".join(selected) + text[match.end():]
    temporary = path.with_name(path.name + ".tvp-production")
    with temporary.open("xb") as stream:
        stream.write(result.encode("utf-8"))
        os.fchmod(stream.fileno(), stat.S_IMODE(mode.st_mode))
    os.replace(temporary, path)


if __name__ == "__main__":
    prepare(Path(sys.argv[1]))
