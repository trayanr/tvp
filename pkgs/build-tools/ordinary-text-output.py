"""Relocate installed prefix slots; validate the entire tree before any writes.

ELF prefix replacements keep their length by adding redundant directory separators.
Installed helper interpreters and embedded shell defaults are selected together.
"""
import json
import re
import shlex
import os
from pathlib import Path
import stat
import struct
import sys
import subprocess
from collections import Counter

root = Path(sys.argv[1])
if root.is_symlink():
    raise ValueError('output root must not be a symlink')
root = root.resolve(strict=True)
old = os.fsencode(sys.argv[2])
new = os.fsencode(str(root))
config = json.loads(sys.argv[4])
assert len(new) <= len(old)
changes = []
link_changes = []
rpaths = []
inodes = Counter()
links = {}
patchelf = sys.argv[3]

def inspect(binary, *arguments):
    if not os.path.isabs(binary):
        raise ValueError(('expected absolute selected inspection tool', binary))
    result = subprocess.run([binary, *map(str, arguments)], capture_output=True,
                            env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode or result.stderr:
        raise ValueError(('ELF inspection failed', binary, result.returncode,
                          result.stderr.decode(errors='replace')))
    return result.stdout

def dynamic_elf(path, data):
    if len(data) < 64 or data[4:7] != b'\x02\x01\x01':
        raise ValueError(('expected native ELF64 little-endian', path))
    kind, machine, version = struct.unpack_from('<HHI', data, 16)
    if kind not in (1, 2, 3) or machine != 62 or version != 1:
        raise ValueError(('unsupported native ELF', path))
    headers = inspect(config['readelf'], '--wide', '--file-header',
                      '--program-headers', '--section-headers', path)
    # Only program-header rows start with these tags; section rows start with [N].
    dynamic = re.search(rb'(?m)^\s*DYNAMIC\s', headers) is not None
    interpreter = re.search(rb'(?m)^\s*INTERP\s', headers) is not None
    if interpreter and not dynamic:
        raise ValueError(('ELF interpreter without dynamic segment', path))
    if kind == 1 and (dynamic or interpreter):
        raise ValueError(('relocatable ELF has runtime segments', path))
    return dynamic

for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        p = Path(directory) / name
        st = p.lstat()
        if stat.S_ISLNK(st.st_mode):
            raw = os.readlink(p)
            if raw.startswith(os.fsdecode(old) + '/'):
                target = root / raw[len(os.fsdecode(old)) + 1:]
                assert target.resolve(strict=True).is_relative_to(root), ('escaping self alias', p)
                link_changes.append((p, os.path.relpath(target, p.parent)))
            else:
                target = p.resolve(strict=True)
                assert target.is_relative_to(root), ('escaping symlink', p)
                assert not os.path.isabs(raw), ('absolute symlink', p)
        elif stat.S_ISREG(st.st_mode):
            inode = (st.st_dev, st.st_ino)
            inodes[inode] += 1
            links[inode] = st.st_nlink
            data = p.read_bytes()
            if data.startswith(b'\x7fELF') and old in data:
                if dynamic_elf(p, data):
                    raw = inspect(patchelf, '--print-rpath', p).removesuffix(b'\n')
                    relocated = raw.replace(old, new)
                    if relocated != raw:
                        rpaths.append((p, relocated))
            if data.startswith(b'\x7fELF') or b'\0' in data:
                replaced = data.replace(old, new + b'/' * (len(old) - len(new)))
            else:
                replaced = data.replace(old, new)
                if replaced.startswith(b'#!') and (p.is_relative_to(root/'bin') or p.is_relative_to(root/'lib')):
                    first, body = replaced.split(b'\n', 1)
                    shell = re.fullmatch(rb'#![ \t]*/(?:[^ \t\n]+/)*(?:sh|bash)(?: (-e|-))?', first)
                    awk = re.fullmatch(rb'#![ \t]*/(?:[^ \t\n]+/)*(?:awk|gawk)([ \t]+-[Mf]+)?', first)
                    if shell:
                        body = body.replace(config['buildShell'].encode(), config['shell'].encode())
                        body = body.replace(b'/bin/sh', config['shell'].encode())
                        preamble = ('PATH=' + shlex.quote(str(root/'bin') + ':' + ':'.join(config['paths']))
                                    + ':"${PATH-}"\nexport PATH\nSHELL=' + shlex.quote(config['shell']) + '\nexport SHELL\n').encode()
                        replaced = b'#!' + config['shell'].encode() + (b' '+shell[1] if shell[1] else b'') + b'\n' + preamble + body
                    elif awk:
                        replaced = b'#!' + new + b'/bin/gawk' + (awk[1] or b'') + b'\n' + body
                    else:
                        raise ValueError(('unexpected installed frontend', p, first))
            assert old not in replaced, p
            if replaced != data or st.st_nlink > 1:
                changes.append((p, replaced, stat.S_IMODE(st.st_mode)))
        elif not stat.S_ISDIR(st.st_mode):
            raise ValueError(('special file', p))
assert all(inodes[k] == n for k, n in links.items()), 'hardlink escapes output'
for p, target in link_changes:
    assert not os.path.lexists(str(p) + '.tvp-relocating'), ('alias collision', p)
for p, data, mode in changes:
    tmp = p.with_name(p.name + '.tvp-relocating')
    assert not tmp.exists() and not tmp.is_symlink(), tmp
for p, data, mode in changes:
    tmp = p.with_name(p.name + '.tvp-relocating')
    assert not tmp.exists() and not tmp.is_symlink(), tmp
    with tmp.open('xb') as stream:
        stream.write(data)
    tmp.chmod(mode)
    tmp.replace(p)
for p, target in link_changes:
    temp = p.with_name(p.name + '.tvp-relocating')
    temp.symlink_to(target)
    temp.replace(p)
# Repair only artifact-prefix substitutions recorded before the fixed-width copy.
# Preserve loader tokens, symlink-sensitive '..', empty entries and user spelling.
for p, rpath in rpaths:
    subprocess.run([patchelf, '--set-rpath', rpath, str(p)], check=True)
print('relocated', len(changes), 'installed files')
