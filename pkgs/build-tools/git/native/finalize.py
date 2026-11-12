"""Bind only source-reserved Git shell slots and installed interpreter text.

The artifact prefix must be absent even before mutation: native fallback is the
stable configurePrefix. Inspect all payloads/aliases before writing changed data.
Both primitive modules are explicit store-file arguments, with no sibling import.
"""
import importlib.util
import json
import os
from pathlib import Path
import sys

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

m = load('installed_tree', sys.argv[4])
elf = load('elf', sys.argv[5])
root, files, groups, links = m.tree(Path(sys.argv[1]))
old = os.fsencode(sys.argv[2])
bindings = json.loads(sys.argv[3])
assert set(bindings) == {'shell', 'perl', 'python'}
marker = b'\0TVP_ORDINARY_SHELL_' + b'X' * 238
before, after = [s.encode() for s in bindings['shell']]
slot = before + marker
assert len(after) < len(slot) and b'\0' not in after
changes, count = [], 0
for name, target in links.items():
    if old in os.fsencode(target):
        raise ValueError(('artifact link in runtime-prefix Git', name))
for group in groups:
    p = files[group[0]]
    data = p.read_bytes()
    if old in data:
        raise ValueError(('artifact bytes in runtime-prefix Git', group))
    result = data
    if marker in data:
        if not all(n.startswith(('bin/git', 'libexec/git-core/git')) for n in group):
            raise ValueError(('unknown Git slot owner', group))
        hits = elf.inspect(p, slot, sys.argv[6])
        if not hits or len(hits) != data.count(marker):
            raise ValueError(('missing/ambiguous Git shell slots', group))
        for h in hits:
            if h['section'] != '.rodata' or not h['readonlyAllocated'] or not h['prefixAtStringStart']:
                raise ValueError(('unknown Git slot section', h))
        result = data.replace(slot, after + b'\0' * (len(slot) - len(after)))
        count += len(hits)
    if b'\0' not in data and data.startswith(b'#!'):
        m.text(data, p)
        for kind, (a, b) in bindings.items():
            a, b = a.encode(), b.encode()
            # Full interpreter paths, including Perl's generated eval/exec
            # fallback if present. Path boundaries reject partial matches.
            result = m.replace_paths(result, a, b)
    if marker in result:
        raise ValueError(('unbound Git shell slot', group))
    if result != data:
        changes.append((p, result, p.stat()))
if not count:
    raise ValueError('no installed native Git shell slots')
for p, result, st in changes:
    p.write_bytes(result)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
