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
commands = {'bzip2': ['bzgrep', 'bzmore', 'bzdiff'], 'zlib': [],
            'xz': ['xzdiff', 'xzgrep', 'xzmore', 'xzless'],
            'zstd': ['zstdgrep', 'zstdless']}[config['family']]
assert len(new) <= len(old)
changes = []
link_changes = []
rpaths = []
inodes = Counter()
links = {}
patchelf = sys.argv[3]
for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        p = Path(directory) / name
        st = p.lstat()
        if stat.S_ISLNK(st.st_mode):
            raw = os.readlink(p)
            aliases = {'bzegrep': 'bzgrep', 'bzfgrep': 'bzgrep', 'bzless': 'bzmore', 'bzcmp': 'bzdiff'}
            alias = aliases.get(p.name) if config['family'] == 'bzip2' and p.parent == root/'bin' else None
            if alias and raw == os.fsdecode(old) + '/bin/' + alias:
                target = root/'bin'/alias
                assert target.is_file() and not target.is_symlink(), ('invalid alias target', p)
                link_changes.append((p, alias))
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
                r = subprocess.run([patchelf, '--print-rpath', str(p)], capture_output=True)
                if r.returncode == 0:
                    raw = r.stdout.removesuffix(b'\n')
                    relocated = raw.replace(old, new)
                    if relocated != raw:
                        rpaths.append((p, relocated))
            if data.startswith(b'\x7fELF') or b'\0' in data:
                replaced = data.replace(old, new + b'/' * (len(old) - len(new)))
            else:
                replaced = data.replace(old, new)
                if p.parent == root / 'bin' and p.name in commands:
                    first, body = replaced.split(b'\n', 1)
                    if not re.fullmatch(rb'#![ \t]*/(?:[^ \t\n]+/)*(?:sh|bash)', first):
                        raise ValueError(('unexpected installed shell frontend', p, first))
                    body = body.replace(config['buildShell'].encode(), config['shell'].encode())
                    body = body.replace(b'/bin/rm -f', b'rm -f')
                    if p.name in {'xzmore', 'bzmore'}:
                        body = body.replace(b'${PAGER:-more}', b'${PAGER:-' + config['pager'].encode() + b'}')
                        body = body.replace(b'${PAGER-more}', b'${PAGER-' + config['pager'].encode() + b'}')
                    preamble = ('PATH=' + shlex.quote(str(root/'bin') + ':' + ':'.join(config['paths']))
                                + ':"${PATH-}"\nexport PATH\nSHELL=' + shlex.quote(config['shell']) + '\nexport SHELL\n').encode()
                    replaced = b'#!' + config['shell'].encode() + b'\n' + (preamble if config['family'] != 'zstd' else b'') + body
            assert old not in replaced, p
            if replaced != data or st.st_nlink > 1:
                changes.append((p, replaced, stat.S_IMODE(st.st_mode)))
        elif not stat.S_ISDIR(st.st_mode):
            raise ValueError(('special file', p))
assert all(inodes[k] == n for k, n in links.items()), 'hardlink escapes output'
man_move = config['family'] == 'bzip2' and (root/'man').exists()
if man_move:
    assert (root/'man').is_dir() and not (root/'man').is_symlink()
    assert not os.path.lexists(root/'share/man'), 'manual layout collision'
    assert not os.path.lexists(root/'share') or ((root/'share').is_dir() and not (root/'share').is_symlink()), 'manual parent is not a directory'
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
if man_move:
    (root/'share').mkdir(exist_ok=True)
    (root/'man').rename(root/'share/man')
# Repair only artifact-prefix substitutions recorded before the fixed-width copy.
# Preserve loader tokens, symlink-sensitive '..', empty entries and user spelling.
for p, rpath in rpaths:
    subprocess.run([patchelf, '--set-rpath', rpath, str(p)], check=True)
print('relocated', len(changes), 'installed files')
