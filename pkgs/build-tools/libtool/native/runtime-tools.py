"""Declare shell utility fallbacks without replacing upstream user overrides."""
import json
from pathlib import Path
import shlex
import sys

root = Path(sys.argv[1])
paths = json.loads(sys.argv[2])
for path in [root / 'bin/libtool', root / 'bin/libtoolize', root / 'bin/libtool-next-version', root / 'share/libtool/build-aux/ltmain.sh']:
    info = path.stat()
    first, body = path.read_bytes().split(b'\n', 1)
    preamble = ('PATH=' + shlex.quote(':'.join(paths)) + ':"${PATH-}"\nexport PATH\n').encode()
    path.write_bytes(first + b'\n' + preamble + body)
    import os
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
