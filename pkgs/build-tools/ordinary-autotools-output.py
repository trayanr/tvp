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
frontends = config['frontends']
if set(frontends) != set(commands) or any(kind not in ('shell', 'perl') for kind in frontends.values()):
    raise ValueError('expected complete frontend interpreter classifications')

def interpreter(first):
    if not first.startswith(b'#!'):
        raise ValueError('expected frontend shebang')
    parts = first[2:].strip().split(None, 1)
    if not parts or not os.path.isabs(parts[0]):
        raise ValueError('expected absolute frontend interpreter')
    name = os.path.basename(parts[0])
    arguments = parts[1] if len(parts) == 2 else b''
    if name == b'env':
        # The shipped tap-driver.pl uses this exact, argument-free env form.
        if arguments not in (b'perl', b'sh', b'bash'):
            raise ValueError('unsupported env frontend interpreter')
        name, arguments = arguments, b''
    kind = {b'perl': 'perl', b'sh': 'shell', b'bash': 'shell'}.get(name)
    if kind is None:
        raise ValueError(('unsupported frontend interpreter', name))
    return kind, arguments

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
        frontend = path.parent == root / 'bin' and path.name in commands
        if b'\0' in data or data.startswith(b'\x7fELF'):
            if frontend:
                raise ValueError(('unsupported binary frontend', path))
            if old in data:
                raise ValueError(('unexpected binary prefix slot', path))
        else:
            for before, after in replacements:
                data = data.replace(before, after)
            script_helper = path.is_relative_to(root / 'share') and data.startswith(b'#!')
            if frontend or script_helper:
                first, body = data.split(b'\n', 1)
                kind, arguments = interpreter(first)
                if frontend and kind != frontends[path.name]:
                    raise ValueError(('unexpected frontend interpreter class', path, kind))
                selected = config.get('perl') if kind == 'perl' else config['shell']
                if not selected:
                    raise ValueError(('missing selected interpreter', path, kind))
                first = b'#!' + os.fsencode(selected) + (b' ' + arguments if arguments else b'')
                if kind == 'perl':
                    preamble = ('BEGIN { $ENV{PATH} = ' + repr(':'.join(config['paths']) + ':')
                                + ' . ($ENV{PATH} // ""); }\n').encode()
                else:
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
