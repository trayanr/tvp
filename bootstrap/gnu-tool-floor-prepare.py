"""Bind release shell scripts without invalidating generated-file timestamps."""
from pathlib import Path
import os
import sys

shell = sys.argv[1].encode()
for path in Path('.').rglob('*'):
    if not path.is_file() or path.is_symlink():
        continue
    info = path.stat()
    data = path.read_bytes()
    for old in (b'#!/bin/sh', b'#!/bin/bash', b'#! /bin/sh'):
        if data.startswith(old + b'\n'):
            path.write_bytes(b'#!' + shell + data[len(old):])
            os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
            break
