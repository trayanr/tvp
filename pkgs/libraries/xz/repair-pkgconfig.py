"""Repair the missing pthread library substitution in XZ 5.0.6."""

from pathlib import Path
import re
import stat
import sys


makefile, metadata = map(Path, sys.argv[1:])
assignments = re.findall(r"^PTHREAD_LIBS = ([^\n]*)$", makefile.read_text(), re.M)
if len(assignments) != 1 or any(character in assignments[0] for character in "@$\\"):
    raise ValueError("Expected resolved PTHREAD_LIBS in the configured Makefile")

info = metadata.lstat()
if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
    raise ValueError("Expected an independent liblzma.pc file")
original = metadata.read_text()
token = "@PTHREAD_LIBS@"
if original.count(token) != 1 or not re.search(r"^Libs\.private: .*@PTHREAD_LIBS@$", original, re.M):
    raise ValueError("Expected one unresolved PTHREAD_LIBS in Libs.private")
metadata.write_text(original.replace(token, assignments[0]))
