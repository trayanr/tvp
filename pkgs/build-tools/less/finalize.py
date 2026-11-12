"""Less 710 source-defined self constants and reserved shell slot only.

Equal-width readonly strings retain offsets, lengths and pooled suffix pointers.
Unknown native owners/shapes fail closed. No archive or arbitrary binary edits.
"""
import importlib.util
import json
import os
from pathlib import Path
import sys
import struct

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

m = load('installed_tree', sys.argv[4])
elf = load('elf', sys.argv[5])
root, files, groups, links = m.tree(Path(sys.argv[1]))
old, new = os.fsencode(sys.argv[2]), os.fsencode(root)
assert len(old) == len(new) and old != new
before, after = [s.encode() for s in json.loads(sys.argv[3])]
marker = b'\0TVP_ORDINARY_SHELL_' + b'X' * 238
slot = before + marker
assert len(after) < len(slot) and b'\0' not in after
# filename.c, lesskey file search and the OSC8 helper's compiled defaults.
# Each is a complete C string; emitted additional forms require source review.
constants = {old + x for x in (
    b'/bin/lessecho', b'/bin/less-osc8-open', b'/etc/sysless',
    b'/etc/syslesskey', b'/bin/.sysless',
)}
changes, link_changes, count = [], [], 0
for name, target in links.items():
    result = os.fsdecode(m.replace_paths(os.fsencode(target), old, new))
    if result != target:
        link_changes.append((root / name, result))
for group in groups:
    p = files[group[0]]
    data = p.read_bytes()
    result = data
    if old in data or marker in data:
        if data.startswith(b'\x7fELF'):
            if not all(n in {'bin/less', 'bin/lessecho', 'bin/lesskey'} for n in group):
                raise ValueError(('unknown Less native owner', group))
            # decode.c's dflt_vartable is a writable byte table, not a C
            # pathname string. Its one source-defined record has a high-bit
            # action byte. Validate that exact record separately; never apply
            # a general writable-data or non-ASCII binary replacement rule.
            if data[4:7] != b'\x02\x01\x01' or len(data) < 64:
                raise ValueError('expected ELF64 little endian')
            kind, machine, version = struct.unpack_from('<HHI', data, 16)
            if kind not in (2, 3) or machine != 62 or version != 1:
                raise ValueError('expected native Less ELF')
            shoff = struct.unpack_from('<Q', data, 40)[0]
            width, number, names = struct.unpack_from('<HHH', data, 58)
            if width != 64 or not 0 < names < number or shoff + number * 64 > len(data):
                raise ValueError('invalid ELF section table')
            records = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + i * 64) for i in range(number)]
            nt = records[names]
            if nt[1] != 3 or nt[4] + nt[5] > len(data):
                raise ValueError('invalid ELF section names')
            strings = data[nt[4]:nt[4] + nt[5]]
            sections = []
            for r in records:
                if r[0] >= len(strings) or strings.find(b'\0', r[0]) < 0:
                    raise ValueError('invalid ELF section name')
                if r[1] != 8 and r[4] + r[5] > len(data):
                    raise ValueError('truncated ELF section')
                sections.append((strings[r[0]:strings.index(b'\0', r[0])], r))
            start = 0
            while True:
                hit = data.find(old, start)
                if hit < 0:
                    break
                owners = [(n, r) for n, r in sections if r[1] != 8 and r[4] <= hit and hit + len(old) <= r[4] + r[5]]
                if len(owners) != 1:
                    raise ValueError('ambiguous Less self constant owner')
                name, r = owners[0]
                begin = max(r[4], data.rfind(b'\0', r[4], hit) + 1)
                end = data.find(b'\0', hit, r[4] + r[5])
                value = data[begin:end] if end >= 0 else None
                readonly = name == b'.rodata' and r[1] == 1 and r[2] & 7 == 2
                table = b'LESS_OSC8_OPEN_ANY\0\x81-' + old + b'/less-osc8-open\0'
                # libexecdir is bin in this profile.
                table = table.replace(old + b'/less-', old + b'/bin/less-')
                table_start = hit - len(b'LESS_OSC8_OPEN_ANY\0\x81-')
                writable_table = (name == b'.data' and r[1] == 1 and r[2] & 7 == 3
                    and table_start >= r[4] and table_start + len(table) <= r[4] + r[5]
                    and data[table_start:table_start + len(table)] == table)
                if not (readonly and begin == hit and value in constants) and not writable_table:
                    raise ValueError(('unknown Less self constant', name, value))
                start = hit + len(old)
            hits = elf.inspect(p, slot, sys.argv[6]) if marker in data else []
            if len(hits) != data.count(marker):
                raise ValueError(('ambiguous Less shell slot', group))
            for h in hits:
                if h['section'] != '.rodata' or not h['readonlyAllocated'] or not h['prefixAtStringStart']:
                    raise ValueError(('unknown Less slot section', h))
            count += len(hits)
            # Every native occurrence was classified above; equal width only.
            result = result.replace(old, new)
            result = result.replace(slot, after + b'\0' * (len(slot) - len(after)))
        else:
            m.text(data, p)
            if not all(n.startswith(('bin/', 'share/', 'etc/', 'nix-support/')) for n in group):
                raise ValueError(('unknown Less text owner', group))
            result = m.replace_paths(data, old, new)
    if old in result or marker in result:
        raise ValueError(('unbound Less payload', group))
    if result != data:
        changes.append((p, result, p.stat()))
if not count:
    raise ValueError('no installed Less declared-shell slot')
for p, result, st in changes:
    p.write_bytes(result)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
for p, target in link_changes:
    p.unlink()
    p.symlink_to(target)
