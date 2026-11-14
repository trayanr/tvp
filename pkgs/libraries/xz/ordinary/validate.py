"""Pre-write guards for the 5.0 archive and installed-script operations.

The inherited compression helpers retain their existing implementation. This
additional contract is selected only by the older XZ procedure, before mutation.
"""
import os
from pathlib import Path
import re
import stat
import sys


def text(path):
    data = path.read_bytes()
    if b'\0' in data:
        raise ValueError(('NUL in text target', path))
    data.decode('utf-8', errors='strict')
    return data


def validate(mode, name):
    root = Path(name)
    if not root.is_absolute() or str(root) != name or root.resolve(strict=True) != root:
        raise ValueError('canonical absolute root required')
    for p in [root, *root.parents]:
        if not stat.S_ISDIR(p.lstat().st_mode):
            raise ValueError(('aliased/non-directory parent', p))
    files = []
    for directory, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            p = Path(directory) / name
            info = p.lstat()
            if stat.S_ISLNK(info.st_mode):
                if (os.path.isabs(os.readlink(p)) or not p.resolve(strict=True).is_relative_to(root)
                        or p.is_dir()):
                    raise ValueError(('unsafe alias', p))
            elif stat.S_ISREG(info.st_mode):
                if info.st_nlink != 1:
                    raise ValueError(('aliased leaf', p))
                files.append(p)
            elif not stat.S_ISDIR(info.st_mode):
                raise ValueError(('special node', p))
    if mode == 'source':
        required = ['configure', 'build-aux/ltmain.sh'] + [
            'src/scripts/' + n + '.in' for n in ('xzdiff', 'xzgrep', 'xzmore', 'xzless')]
        targets = [p for p in files if p.name == 'ltmain.sh' or p == root/'configure'
                   or (p.relative_to(root).parts[0] in {'tests', 'build-aux'}
                       and p.read_bytes().startswith(b'#!'))]
        for n in required:
            if root/n not in files:
                raise ValueError(('regular independent source required', n))
        for n in required[2:]:
            if not text(root/n).startswith(b'#!@POSIX_SHELL@\n'):
                raise ValueError(('unsupported template frontend', n))
        for p in targets:
            data = text(p)
            if p == root/'configure' and not re.match(rb'#![ \t]*/bin/sh\n', data):
                raise ValueError('unsupported configure frontend')
            if p.suffix in {'.sh', '.test'} and data.startswith(b'#!'):
                if not re.fullmatch(rb'#![ \t]*(?:/bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))', data.split(b'\n')[0]):
                    raise ValueError(('unsupported source frontend', p))
    elif mode == 'output':
        for p in files:
            data = p.read_bytes()
            # Binary relocation is a separate inherited operation. Validate every
            # text target in full; installed helpers may never take binary routing.
            if p.parent == root/'bin' and p.name in {'xzdiff', 'xzgrep', 'xzmore', 'xzless'}:
                data = text(p)
                if not re.fullmatch(rb'#![ \t]*/(?:[^ \t\n]+/)*(?:sh|bash)', data.split(b'\n')[0]):
                    raise ValueError(('unsupported installed frontend', p))
            elif b'\0' not in data and not data.startswith(b'\x7fELF'):
                text(p)
        for n in ('xzdiff', 'xzgrep', 'xzmore', 'xzless'):
            if root/'bin'/n not in files:
                raise ValueError(('regular independent installed helper required', n))
        data = text(root/'bin/xzless')
        if data.count(b'$(less -V') != 1 or data.count(b'exec less "$@"') != 1:
            raise ValueError('unsupported xzless pager anchors')
    else:
        raise ValueError('explicit source/output contract required')
    return root


if __name__ == '__main__':
    validate(*sys.argv[1:])
