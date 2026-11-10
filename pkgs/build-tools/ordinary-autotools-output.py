"""Confined text-prefix and installed frontend finalization for ordinary Autotools.

Inventory and validate the whole copied output before writing. Never interpret
loader search paths or write through aliases/hardlinks. Binary prefix slots are
not a supported layout; an unexpected one fails before changing any file.
"""
from collections import Counter
import json
import os
from pathlib import Path
import shlex
import stat
import sys

root = Path(sys.argv[1])
if root.is_symlink():
    raise ValueError('output root is a symlink')
root = root.resolve(strict=True)
old = os.fsencode(sys.argv[2])
config = json.loads(sys.argv[3])
replacements = [(old, os.fsencode(root))] + [
    (os.fsencode(p['old']), os.fsencode(p['new'])) for p in config['replacements']
]
family = config['family']
commands = {
    'autoconf': ['autoconf', 'autoheader', 'autom4te', 'autoreconf', 'autoscan', 'autoupdate', 'ifnames'],
    'automake': ['automake', 'aclocal'],
    'libtool': ['libtool', 'libtoolize'],
}[family]
counts = Counter()
links = {}
changes = []
for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        path = Path(directory) / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            target = path.resolve(strict=True)
            if not target.is_relative_to(root) or os.path.isabs(os.readlink(path)):
                raise ValueError(('escaping/absolute symlink', path))
            continue
        if stat.S_ISDIR(info.st_mode):
            continue
        if not stat.S_ISREG(info.st_mode):
            raise ValueError(('special file', path))
        inode = info.st_dev, info.st_ino
        counts[inode] += 1
        links[inode] = info.st_nlink
        data = path.read_bytes()
        if b'\0' in data or data.startswith(b'\x7fELF'):
            if old in data:
                raise ValueError(('unexpected binary prefix slot', path))
        else:
            for before, after in replacements:
                data = data.replace(before, after)
            shell_helper = (path.is_relative_to(root / 'share') and data.startswith(b'#!')
                            and b'sh' in data.split(b'\n', 1)[0])
            if (path.parent == root / 'bin' and path.name in commands) or shell_helper:
                first, body = data.split(b'\n', 1)
                if b'perl' in first:
                    preamble = ('BEGIN { $ENV{PATH} = ' + repr(':'.join(config['paths']) + ':')
                                + ' . ($ENV{PATH} // ""); }\n').encode()
                else:
                    if not first.startswith(b'#!'):
                        raise ValueError(('expected shell frontend', path))
                    first = ('#!' + config['shell']).encode()
                    preamble = ('PATH=' + shlex.quote(':'.join(config['paths'])) + ':"${PATH-}"\nexport PATH\n').encode()
                data = first + b'\n' + preamble + body
            if old in data:
                raise ValueError(('unrelocated artifact prefix', path))
        if data != path.read_bytes() or info.st_nlink > 1:
            changes.append((path, data, stat.S_IMODE(info.st_mode)))
if any(counts[k] != n for k, n in links.items()):
    raise ValueError('hardlink escapes copied output')
for path, data, mode in changes:
    temporary = path.with_name(path.name + '.tvp-finalizing')
    if temporary.exists() or temporary.is_symlink():
        raise ValueError(('temporary collision', temporary))
for path, data, mode in changes:
    temporary = path.with_name(path.name + '.tvp-finalizing')
    temporary.write_bytes(data)
    temporary.chmod(mode)
    temporary.replace(path)
print('finalized', len(changes), 'installed files')
