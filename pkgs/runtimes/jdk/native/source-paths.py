"""Replace the two declared store-layout patch tokens, failing on drift."""
from pathlib import Path
import sys

for filename, token, value in [
    ("src/java.base/unix/native/libjava/childproc.c", "@TVP_SHELL@", sys.argv[1]),
    ("src/java.desktop/unix/native/common/awt/fontpath.c", "@TVP_FONTCONFIG@", sys.argv[2]),
]:
    path = Path(filename)
    text = path.read_text()
    if text.count(token) != 1:
        raise ValueError(f"expected exactly one {token} in {filename}")
    path.write_text(text.replace(token, value))
