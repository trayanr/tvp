"""Keep the generated production recursion and leave original test rules for U.

Ncurses configure appends one all/install recursion per source subdirectory.
The test directory installs nothing; its all target builds interactive fixtures.
A private root Makefile omits just that recipe, with an exact cardinality guard.
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
if count != 1:
    raise ValueError(("expected one generated test recursion", count))
with Path("Makefile.production").open("xb") as stream:
    stream.write(production)
