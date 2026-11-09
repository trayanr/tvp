"""Give installed shell helpers their declared tools, preserving caller tools."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
config = json.loads(sys.argv[2])
preamble = ('PATH=' + "'" + ':'.join(config['paths']) + ":'\"${PATH-}\"; export PATH\n").encode()
for relative in config['scripts']:
    path = root / relative
    if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != root.parent):
        raise ValueError(f'symlink in installed helper: {path}')
    if path.stat().st_nlink != 1:
        raise ValueError(f'linked helper: {path}')
    first, body = path.read_bytes().split(b'\n', 1)
    if first != ('#!' + config['bash'] + '/bin/bash').encode():
        raise ValueError(f'expected selected Bash: {path}')
    path.write_bytes(first + b'\n' + preamble + body)
