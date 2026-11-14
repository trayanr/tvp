"""Declared shell-string tools for installed Perl frontends; keep override logic."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
paths = json.loads(sys.argv[2])
# Append caller PATH so peer tools (automake, libtoolize, custom helpers) remain
# discoverable without adding a cyclic production dependency to Autoconf.
preamble = ('BEGIN { $ENV{PATH} = ' + repr(':'.join(paths) + ':')
            + ' . ($ENV{PATH} // ""); }\n').encode()
for name in sys.argv[3:]:
    path = root / 'bin' / name
    data = path.read_bytes()
    first, rest = data.split(b'\n', 1)
    if not first.startswith(b'#!') or not first.endswith(b'/bin/perl'):
        raise ValueError(f'{path}: expected declared Perl interpreter')
    path.write_bytes(first + b'\n' + preamble + rest)
