"""Confined preparation for ordinary compression archives, before any source writes.

Validate the complete unpacked tree and every replacement before staging changes.
The package selects the contract explicitly; this is not a version dispatcher.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

family, shell = sys.argv[1:]
if family not in {'bzip2', 'zlib', 'xz', 'zstd'} or not shell.startswith('/'):
    raise ValueError('explicit package and absolute shell required')
root = Path.cwd()
if root.is_symlink():
    raise ValueError('source root must be a directory')
root = root.resolve(strict=True)
files = []
for directory, dirs, names in os.walk(root, followlinks=False):
    for name in sorted(dirs + names):
        path = Path(directory) / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            if os.path.isabs(os.readlink(path)) or not path.resolve(strict=True).is_relative_to(root):
                raise ValueError(('unsafe source symlink', path))
            if path.is_dir():
                raise ValueError(('directory alias', path))
        elif stat.S_ISREG(info.st_mode):
            if info.st_nlink != 1:
                raise ValueError(('source hardlink', path))
            files.append(path)
        elif not stat.S_ISDIR(info.st_mode):
            raise ValueError(('special source file', path))
changes = {}
required = {'bzip2': ['Makefile', 'Makefile-libbz2_so', 'bzlib.h'],
            'zlib': ['configure', 'Makefile.in', 'zlib.h'],
            'xz': ['configure', 'src/scripts/xzgrep.in', 'src/scripts/xzmore.in'],
            'zstd': ['Makefile', 'lib/Makefile', 'programs/Makefile', 'tests/cli-tests/run.py']}[family]
for name in required:
    if root / name not in files:
        raise ValueError(('missing independent source target', name))
if family in {'zlib', 'xz'}:
    path = root / 'configure'
    data = path.read_bytes()
    if not re.match(rb'#![ \t]*/bin/sh\n', data):
        raise ValueError('expected original configure /bin/sh frontend')
    changes[path] = b'#!' + shell.encode() + b'\n' + changes.get(path, data).split(b'\n', 1)[1]
if family == 'xz':
    for path in files:
        data = path.read_bytes()
        if path.name == 'ltmain.sh':
            search = b' '.join(f[2:].encode() for f in os.environ.get('NIX_LDFLAGS', '').split() if f.startswith('-L'))
            data, count = re.subn(rb'eval (sys_lib_search_path=).*', lambda m: m[1] + b"'" + search + b"'", data)
            if count != 1:
                raise ValueError(('ltmain search anchor', path, count))
            data = re.sub(rb'eval sys_lib_.+search_path=.*', b'', data)
            changes[path] = data
        if path == root / 'configure':
            changes[path] = changes[path].replace(b'/usr/bin/file', b'file')
        if path.parts[len(root.parts)] in {'tests', 'build-aux'} and data.startswith(b'#!'):
            front = data.split(b'\n', 1)[0]
            if re.fullmatch(rb'#![ \t]*(?:/bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))', front):
                changes[path] = b'#!' + shell.encode() + b'\n' + changes.get(path, data).split(b'\n', 1)[1]
            elif path.suffix in {'.sh', '.test'}:
                raise ValueError(('unexpected source shell frontend', path, front))
if family == 'zstd':
    # Python runner is invoked by the declared Python; do not rewrite its frontend.
    if not (root / 'tests/cli-tests/run.py').read_bytes().startswith(b'#!/usr/bin/env python3\n'):
        raise ValueError('unexpected upstream Python frontend')
    for path in files:
        if path.is_relative_to(root / 'tests/cli-tests') and path.suffix == '.sh':
            data = path.read_bytes()
            if not data.startswith(b'#!'):
                if path.parent.name != 'common':
                    raise ValueError(('missing CLI test frontend', path))
                continue
            if not re.match(rb'#![ \t]*(?:/bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))\n', data):
                raise ValueError(('unexpected CLI test shell', path))
            changes[path] = b'#!' + shell.encode() + b'\n' + changes.get(path, data).split(b'\n', 1)[1]
# All validation, including collisions, precedes the first write.
for path in changes:
    if os.path.lexists(str(path) + '.tvp-prepare'):
        raise ValueError(('preparation collision', path))
for path, data in changes.items():
    info = path.stat()
    temp = Path(str(path) + '.tvp-prepare')
    with temp.open('xb') as stream:
        stream.write(data)
    os.chmod(temp, stat.S_IMODE(info.st_mode))
    os.utime(temp, ns=(info.st_atime_ns, info.st_mtime_ns))
for path in changes:
    os.replace(str(path) + '.tvp-prepare', path)
print(json.dumps({'family': family, 'validatedFiles': len(files), 'adaptations': {
    str(path.relative_to(root)): hashlib.sha256(data).hexdigest() for path, data in changes.items()
}}, sort_keys=True))
