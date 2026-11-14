"""Read-only confinement preflight for the shared Autotools preparation step."""
import os
from pathlib import Path
import re
import stat

root = Path.cwd().resolve(strict=True)
targets = {root / 'configure'}
for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        path = Path(directory) / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            if os.path.isabs(os.readlink(path)) or not path.resolve(strict=True).is_relative_to(root):
                raise ValueError(('escaping source symlink', path))
        if name == 'ltmain.sh':
            targets.add(path)
for path in sorted(targets):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError(('preparation target must be an independent regular file', path))
if not re.match(rb'#![ \t]*/bin/sh\n', (root / 'configure').read_bytes()):
    raise ValueError('expected original configure /bin/sh shebang')
print('confined', len(targets), 'source preparation targets')
