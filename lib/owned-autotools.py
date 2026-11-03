"""Explicit native Autotools shell and system-library search preparation."""
import os
from pathlib import Path
import re
import sys

shell = sys.argv[1].encode()
for path in [*Path('.').rglob('ltmain.sh'), Path('configure')]:
    info = path.stat()
    data = path.read_bytes()
    if path.name == 'ltmain.sh':
        # Autoconf must use declared linker paths, never host system searches.
        flags = os.environ.get('NIX_LDFLAGS', '').split()
        search = b' '.join(f[2:].encode() for f in flags if f.startswith('-L'))
        data = re.sub(rb'eval (sys_lib_search_path=).*', lambda m: m[1] + b"'" + search + b"'", data)
        data = re.sub(rb'eval sys_lib_.+search_path=.*', b'', data)
    else:
        if not re.match(rb'#![ \t]*/bin/sh\n', data):
            raise ValueError('expected configure /bin/sh shebang')
        data = b'#!' + shell + b'\n' + data.split(b'\n', 1)[1]
        data = data.replace(b'/usr/bin/file', b'file')
    path.write_bytes(data)
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
