"""Relocate the pre-ICU 56 DEFAULT_ICU_PLUGINS string without moving ELF data."""

import os
from pathlib import Path
import sys

output, artifact = map(Path, sys.argv[1:])
libraries = [
    path
    for path in (output / "lib").glob("libicuuc.so.*")
    if path.is_file() and not path.is_symlink()
]
if len(libraries) != 1:
    raise ValueError(f"Expected one ICU common shared library, found {libraries}")

library = libraries[0]
old = os.fsencode(artifact / "lib/icu")
new = os.fsencode(output / "lib/icu")
data = library.read_bytes()
needle = b"\0" + old + b"\0"
if not data.startswith(b"\x7fELF") or data.count(needle) != 1 or len(new) > len(old):
    raise ValueError(f"Unexpected ICU plug-in directory storage in {library}")

replacement = b"\0" + new.ljust(len(old), b"\0") + b"\0"
library.write_bytes(data.replace(needle, replacement))
