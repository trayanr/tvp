"""Bind only Gawk 3's source-defined AWKPATH and locale readonly ELF strings.

Use the established ELF inspector and installed-tree primitives. Unknown native
or structured prefix storage fails before writes; no arbitrary binary replacement.
"""
import importlib.util
import os
import re
import shlex
from pathlib import Path
import sys


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def compiled(data, hits, old, new):
    if len(old) != len(new):
        raise ValueError('equal-width Gawk prefixes required')
    allowed = {b'.:' + old + b'/share/awk', old + b'/share/locale'}
    spans = set()
    for h in hits:
        a, b = h['stringStart'], h['stringEnd']
        if (h['section'] != '.rodata' or not h['readonlyAllocated']
                or b < 0 or data[a:b] not in allowed):
            raise ValueError(('unknown Gawk compiled path slot', h))
        spans.add((a, b))
    result = data
    for a, b in spans:
        result = result[:a] + data[a:b].replace(old, new) + result[b:]
    if old in result:
        raise ValueError('unowned Gawk ELF prefix')
    return result


def bind_shell(data, hits, shell):
    slot = b'/bin/sh\0TVP_ORDINARY_SHELL_' + b'X' * 238
    if not hits or len(hits) != data.count(slot) or len(shell) >= len(slot):
        raise ValueError('missing/ambiguous reserved Gawk shell')
    for h in hits:
        if h['section'] != '.rodata' or not h['readonlyAllocated'] or not h['prefixAtStringStart']:
            raise ValueError(('unowned Gawk shell slot', h))
    return data.replace(slot, shell + b'\0' * (len(slot) - len(shell)))


def main():
    m = load('installed_tree', sys.argv[3])
    elf = load('elf', sys.argv[4])
    root, files, groups, links = m.tree(Path(sys.argv[1]))
    old, new = os.fsencode(sys.argv[2]), os.fsencode(root)
    changes, aliases = [], []
    for group in groups:
        p = files[group[0]]
        data = p.read_bytes()
        slot = b'/bin/sh\0TVP_ORDINARY_SHELL_' + b'X' * 238
        frontend = "bin/igawk" in group
        if old not in data and slot not in data and not frontend:
            continue
        if data.startswith(b'\x7fELF'):
            if not all(n.startswith('bin/') and Path(n).name in {'gawk', 'pgawk', 'gawk-3.0.6', 'gawk-3.1.8', 'pgawk-3.1.8'} for n in group):
                raise ValueError(('unknown Gawk ELF owner', group))
            result = compiled(data, elf.inspect(p, old, sys.argv[5]), old, new)
            if slot in data:
                result = bind_shell(result, elf.inspect(p, slot, sys.argv[5]), os.fsencode(sys.argv[6]))
        else:
            result = m.replace_paths(m.text(data, p), old, new)
        if frontend:
            if set(group) != {'bin/igawk'} or not re.match(rb'#![ \t]*(?:/bin/sh|/nix/store/[^/]+/bin/bash)\n', data):
                raise ValueError('unexpected igawk shell frontend')
            first, body = result.split(b'\n', 1)
            paths = str(root / 'bin') + (':' + sys.argv[7] if len(sys.argv) > 7 and sys.argv[7] else '')
            body = ('PATH=' + shlex.quote(paths) + ':"${PATH-}"\nexport PATH\nSHELL=' + shlex.quote(sys.argv[6]) + '\nexport SHELL\n').encode() + body
            result = first + b'\n' + body
        changes.append((p, result, p.stat()))
    for name, target in links.items():
        relocated = m.replace_paths(os.fsencode(target), old, new).decode()
        if relocated.startswith(str(root) + '/'):
            relocated = os.path.relpath(relocated, (root / name).parent)
        if not ((root / name).parent / relocated).resolve(strict=True).is_relative_to(root):
            raise ValueError(('outside Gawk alias', name))
        aliases.append((root / name, target, relocated))
    for p, result, st in changes:
        p.write_bytes(result)
        os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
    for p, before, after in aliases:
        if before != after:
            p.unlink(); p.symlink_to(after)
    m.audit(root, [os.fsdecode(old)])


if __name__ == '__main__':
    main()
