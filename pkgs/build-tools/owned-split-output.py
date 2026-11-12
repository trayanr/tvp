"""Relocate the public build tools' installed trees before their existing fixups.

Compiled prefixes use equal-width artifact names: no ELF offsets, archive member
sizes or embedded lengths change. Runtime C-string slots are reserved explicitly
by the few procedures that embed a shell. Plan all changes before writing, retain
internal hardlinks, and reject unrecognized binary prefix occurrences.
"""
import gzip
import json
import os
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve(strict=True)
old = os.fsencode(sys.argv[2])
new = os.fsencode(root)
config = json.loads(sys.argv[3])
import importlib.util
spec = importlib.util.spec_from_file_location("installed_tree", sys.argv[4])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
tree, replace_paths = module.tree, module.replace_paths

def relocate_paths(data):
    # Installed makefiles may expand -I/-L/-R directly against their prefix.
    # Validate each occurrence with the shared path-boundary rule, allowing
    # those explicit compiler option tokens while rejecting arbitrary substrings.
    start = 0
    while True:
        pos = data.find(old, start)
        if pos < 0:
            break
        flag = data[max(0, pos - 2):pos]
        token = pos == 2 or data[pos - 3:pos - 2] in (b" ", b"\t", b"\n", b"'", b'"', b"=")
        left = pos if flag in (b'-I', b'-L', b'-R') and token else max(0, pos - 1)
        replace_paths(data[left:pos + len(old) + 1], old, new)
        start = pos + len(old)
    return data.replace(old, new)


root, files, groups, links = tree(root)
changes = []
link_changes = []
for name, target in links.items():
    relocated = os.fsdecode(relocate_paths(os.fsencode(target)))
    if relocated != target:
        link_changes.append((root / name, relocated))
for group in groups:
    p = files[group[0]]
    data = p.read_bytes()
    compressed = data.startswith(b'\x1f\x8b')
    payload = gzip.decompress(data) if compressed else data
    binary = b'\0' in payload
    result = payload
    if old in result:
        if binary:
            if not (result.startswith(b'\x7fELF') or result.startswith(b'!<arch>\n')):
                raise ValueError(('unknown binary prefix storage', p))
            if len(old) != len(new):
                raise ValueError('compiled prefix width changed')
        result = relocate_paths(result)
    for before, after in config.get('text', []):
        if not binary:
            result = result.replace(before.encode(), after.encode())
    for before, after in config.get('slots', []):
        before, after = before.encode(), after.encode()
        slot = before + b'\0TVP_ORDINARY_SHELL_' + b'X' * 238
        if slot in result:
            if len(after) >= len(slot):
                raise ValueError('runtime shell exceeds reserved C-string slot')
            result = result.replace(slot, after + b'\0' * (len(slot) - len(after)))
    for before, after in config.get('fixed', []):
        before, after = before.encode(), after.encode()
        if len(before) != len(after):
            raise ValueError('runtime path width changed')
        result = result.replace(before, after)
    if old in result or b'TVP_ORDINARY_SHELL_' + b'X' * 238 in result:
        raise ValueError(('unrelocated installed slot', p))
    if result != payload:
        if compressed:
            result = gzip.compress(result, mtime=0)
        changes.append((group, result, p.stat()))
for group, data, st in changes:
    # In-place writes preserve the copy's internal hardlinks and inode modes.
    p = files[group[0]]
    p.write_bytes(data)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
for p, target in link_changes:
    p.unlink()
    p.symlink_to(target)
