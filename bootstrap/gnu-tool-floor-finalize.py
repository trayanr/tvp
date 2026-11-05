"""Strip only installed ELF/archive data; failures are build errors."""
from pathlib import Path
import subprocess
import sys

root, strip = sys.argv[1:]
for path in sorted(Path(root).rglob('*')):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open('rb') as stream:
        head = stream.read(8)
    if head.startswith(b'\x7fELF') or head == b'!<arch>\n':
        subprocess.run([strip, '--strip-debug', str(path)], check=True)
