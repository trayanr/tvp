"""Replace the two declared store-layout patch tokens, failing on drift."""
from pathlib import Path
import stat
import sys


def source_file(filename):
    path = Path.cwd()
    parts = Path(filename).parts
    if Path(filename).is_absolute() or not parts or '..' in parts:
        raise ValueError(f"expected a relative source path: {filename}")
    for index, part in enumerate(parts):
        path = path / part
        mode = path.lstat().st_mode
        expected = stat.S_ISREG if index == len(parts) - 1 else stat.S_ISDIR
        if not expected(mode):
            raise ValueError(f"expected regular source files and directories: {filename}")
    return path


replacements = []
for filename, token, value in [
    ("src/java.base/unix/native/libjava/childproc.c", "@TVP_SHELL@", sys.argv[1]),
    ("src/java.desktop/unix/native/common/awt/fontpath.c", "@TVP_FONTCONFIG@", sys.argv[2]),
]:
    path = source_file(filename)
    text = path.read_text()
    if text.count(token) != 1:
        raise ValueError(f"expected exactly one {token} in {filename}")
    replacements.append((path, text.replace(token, value)))

# Validate every target and token before modifying either source file.
for path, text in replacements:
    path.write_text(text)
