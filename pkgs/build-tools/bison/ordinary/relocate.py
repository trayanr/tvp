"""Relocate installed prefix slots; validate the entire tree before any writes.

ELF prefix replacements keep their length by adding redundant directory separators.
The dedicated shell C-string slot is NUL padded, preserving every ELF offset.
"""
import os
from pathlib import Path
import stat
import sys
import subprocess
from collections import Counter

root = Path(sys.argv[1]).resolve(strict=True)
old = os.fsencode(sys.argv[2])
new = os.fsencode(str(root))
build_shell = os.fsencode(sys.argv[3]) if len(sys.argv) == 6 else None
shell = os.fsencode(sys.argv[4]) if len(sys.argv) == 6 else None
marker = b'TVP_ORDINARY_SHELL_' + b'X' * 238
assert len(marker) == 257
assert len(new) <= len(old)
changes = []
inodes = Counter()
links = {}
patchelf = sys.argv[-1]
for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        p = Path(directory) / name
        st = p.lstat()
        if stat.S_ISLNK(st.st_mode):
            target = p.resolve(strict=True)
            assert target.is_relative_to(root), ('escaping symlink', p)
            raw = os.readlink(p)
            assert not os.path.isabs(raw), ('absolute symlink', p)
        elif stat.S_ISREG(st.st_mode):
            inode = (st.st_dev, st.st_ino)
            inodes[inode] += 1
            links[inode] = st.st_nlink
            data = p.read_bytes()
            if data.startswith(b'\x7fELF') or b'\0' in data:
                replaced = data.replace(old, new + b'/' * (len(old) - len(new)))
                if shell is not None and marker in replaced:
                    assert len(shell) < len(marker)
                    slot = build_shell + b'\0' + marker
                    assert slot in replaced, p
                    replaced = replaced.replace(slot, shell + b'\0' * (len(slot)-len(shell)))
            else:
                replaced = data.replace(old, new)
            assert old not in replaced, p
            if shell is not None:
                assert marker not in replaced, p
            if replaced != data or st.st_nlink > 1:
                changes.append((p, replaced, stat.S_IMODE(st.st_mode)))
        elif not stat.S_ISDIR(st.st_mode):
            raise ValueError(('special file', p))
assert all(inodes[k] == n for k, n in links.items()), 'hardlink escapes output'
for p, data, mode in changes:
    tmp = p.with_name(p.name + '.tvp-relocating')
    assert not tmp.exists() and not tmp.is_symlink(), tmp
for p, data, mode in changes:
    tmp = p.with_name(p.name + '.tvp-relocating')
    assert not tmp.exists() and not tmp.is_symlink(), tmp
    tmp.write_bytes(data)
    tmp.chmod(mode)
    tmp.replace(p)
# RPATH is structured ELF metadata. Canonicalize its directory spelling after
# same-width string-slot relocation, before the normal RPATH policy runs.
for directory, dirs, files in os.walk(root, followlinks=False):
    for name in files:
        p = Path(directory) / name
        if p.is_symlink() or p.read_bytes()[:4] != b'\x7fELF':
            continue
        r = subprocess.run([patchelf, '--print-rpath', str(p)], capture_output=True)
        if r.returncode == 0 and r.stdout.strip():
            raw = r.stdout.decode().strip()
            normalized = ':'.join(os.path.normpath(x) for x in raw.split(':'))
            if raw != normalized:
                subprocess.run([patchelf, '--set-rpath', normalized, str(p)],check=True)
print('relocated', len(changes), 'installed files')
