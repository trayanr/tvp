"""Move the PHP 5.2/5.3 SDK's generated shell header before M4 comments."""
import os
from pathlib import Path
import re


def normalize_configure(path):
    info = path.stat()
    data = path.read_bytes()
    if b'\0' in data:
        raise ValueError('unexpected NUL in legacy configure')
    offset = 0
    for line in data.splitlines(keepends=True):
        if re.fullmatch(rb'#![ \t]*/bin/sh\n', line):
            if offset:
                path.write_bytes(line + data[:offset] + data[offset + len(line):])
                os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
            return
        if line.lstrip().startswith(b'#!') or not re.fullmatch(rb'[ \t]*(?:#[^\n]*)?\n', line):
            raise ValueError('expected only comments before configure /bin/sh shebang')
        offset += len(line)
    raise ValueError('expected configure /bin/sh shebang')


if __name__ == '__main__':
    normalize_configure(Path('configure'))
