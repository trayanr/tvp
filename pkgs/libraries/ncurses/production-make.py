"""Keep the generated production recursion and leave original test rules for U.

Ncurses appends a common recursion for each source subdirectory and another
library/module recursion for directories with a modules file. The test directory
has both; neither belongs in production. Keep every other directory unchanged.
"""
from pathlib import Path
import re
import stat

source = Path("Makefile")
info = source.lstat()
if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
    raise ValueError("expected independent generated Makefile")
data = source.read_bytes()
if b"\0" in data:
    raise ValueError("NUL in generated Makefile")
pattern = rb'(?m)^\t(?:cd test && \$[({]MAKE[)}][^\n]*|\( cd "?test"? && \$[({]MAKE[)}][^\n]*\))\n'
production, count = re.subn(pattern, b"", data)
if count != 2:
    raise ValueError(("expected common and module test recursions", count))
with Path("Makefile.production").open("xb") as stream:
    stream.write(production)
