"""Guarded equal-width shared Perl finalization, x86_64 ELF64 only.

Plan the whole tree before writes. Compiled library path strings must begin at
NUL boundaries in allocated readonly .rodata. Equal widths preserve all string
positions, suffixes, compiled lengths and terminators (including pooled suffix
addresses). Dynamic paths are changed only through the selected ELF tool.
Text and symlinks use exact pathname boundaries. No receipts in the output.
"""
from pathlib import Path
import struct
import subprocess


def inspect(path, prefix, readelf):
    path = Path(path)
    data = path.read_bytes()
    if not data.startswith(b'\x7fELF') or data[4:7] != b'\x02\x01\x01' or len(data) < 64:
        raise ValueError('expected ELF64 little endian')
    kind, machine, version = struct.unpack_from('<HHI', data, 16)
    if kind not in (2, 3) or machine != 62 or version != 1:
        raise ValueError('expected x86_64 executable/shared ELF')
    if not str(readelf).startswith('/nix/store/'):
        raise ValueError('explicit store readelf required')
    result = subprocess.run([str(readelf), '-W', '-h', '-l', '-S', '-d', str(path)],
                            capture_output=True, check=True)
    if result.stderr:
        raise ValueError(('readelf diagnostics', result.stderr))
    shoff = struct.unpack_from('<Q', data, 40)[0]
    shentsize, shnum, names = struct.unpack_from('<HHH', data, 58)
    if shentsize != 64 or not shnum or not 0 < names < shnum or shoff + 64 * shnum > len(data):
        raise ValueError('invalid/extended section table')
    records = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + 64 * i) for i in range(shnum)]
    table = records[names]
    if table[1] != 3 or table[4] + table[5] > len(data):
        raise ValueError('invalid section string table')
    strings = data[table[4]:table[4] + table[5]]
    sections = []
    for record in records:
        noff, typ, flags, address, offset, size, link, info, align, entsize = record
        if noff >= len(strings) or strings.find(b'\0', noff) < 0:
            raise ValueError('invalid section name')
        if typ != 8 and offset + size > len(data):
            raise ValueError('truncated section')
        sections.append((strings[noff:strings.index(b'\0', noff)].decode('ascii'), typ, flags, offset, size))
    hits, start = [], 0
    while True:
        hit = data.find(prefix, start)
        if hit < 0:
            break
        owners = [s for s in sections if s[1] != 8 and s[3] <= hit and hit + len(prefix) <= s[3] + s[4]]
        if len(owners) != 1:
            raise ValueError(('prefix has no unique section', hit))
        name, typ, flags, offset, size = owners[0]
        begin = data.rfind(b'\0', offset, hit) + 1
        begin = max(begin, offset)
        end = data.find(b'\0', hit, offset + size)
        # Mapping alone does not prove no code/relocations point into a string.
        hits.append({'offset': hit, 'section': name, 'sectionType': typ, 'flags': flags,
                     'stringStart': begin, 'stringEnd': end,
                     'string': data[begin:end].decode('ascii') if end >= 0 else None,
                     'prefixAtStringStart': begin == hit,
                     'readonlyAllocated': bool(flags & 2) and not bool(flags & 5)})
        start = hit + len(prefix)
    return hits


import json
import os
import re
import stat
import sys


def text(data, name):
    if b'\0' in data:
        raise ValueError(('NUL in installed text', name))
    data.decode('utf-8', errors='strict')
    return data


def replace_paths(data, old, new):
    # The prefix is a complete store basename, never a substring of another
    # pathname. Quotes, separators and whitespace delimit standalone prefixes.
    allowed = b"/\x00\n\r\t '\";:),]}<>"
    start = 0
    while True:
        pos = data.find(old, start)
        if pos < 0:
            break
        end = pos + len(old)
        if (pos and (chr(data[pos-1]).isalnum() or data[pos-1] in b'/_+-.')) or (end < len(data) and data[end] not in allowed):
            raise ValueError(('non-path prefix occurrence', pos))
        start = end
    return data.replace(old, new)


def tree(root):
    root = Path(root)
    if not root.is_absolute() or str(root) != str(root.resolve(strict=True)):
        raise ValueError('canonical absolute installed root required')
    for p in [root, *root.parents]:
        if not stat.S_ISDIR(p.lstat().st_mode):
            raise ValueError(('symlink/non-directory parent', p))
    files, links, groups = {}, {}, {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        for n in sorted(dirs + names):
            p = Path(directory)/n
            st = p.lstat(); name = str(p.relative_to(root))
            if stat.S_ISREG(st.st_mode):
                files[name] = p
                groups.setdefault((st.st_dev, st.st_ino), []).append(name)
            elif stat.S_ISLNK(st.st_mode):
                links[name] = os.readlink(p)
            elif not stat.S_ISDIR(st.st_mode):
                raise ValueError(('special installed node', name))
    for group in groups.values():
        if files[group[0]].stat().st_nlink != len(group):
            raise ValueError(('outside hardlink alias', group))
    return root, files, list(groups.values()), links


def finalize(config):
    root, files, groups, links = tree(config['root'])
    old, new = config['artifact'].encode(), str(root).encode()
    if len(old) != len(new) or old == new or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+', old):
        raise ValueError('distinct equal-width artifact/final prefixes required')
    for k in ('readelf', 'patchelf'):
        p = config[k]
        if not p.startswith('/nix/store/') or not os.path.isfile(p) or not os.access(p, os.X_OK):
            raise ValueError(('missing explicit inspector', p))
    changes, dynamic, mappings, linkchanges = {}, {}, {}, {}
    for group in groups:
        name = group[0]; p = files[name]; data = p.read_bytes()
        metadata = (p.name in ('Config.pm', 'Config_heavy.pl', '.packlist', 'config.sh')
                    or '/CORE/' in '/' + name and p.suffix in ('.h', '.c', '.inc'))
        if metadata:
            text(data, name)  # Corrupt metadata never selects binary routing.
        if data.startswith(b'\x7fELF'):
            hits = inspect(p, old, config['readelf'])
            mappings[name] = hits
            cp = subprocess.run([config['patchelf'], '--print-rpath', str(p)], check=True, capture_output=True)
            if cp.stderr or not cp.stdout.endswith(b'\n'):
                raise ValueError(('invalid RPATH inspection', name))
            rpath = cp.stdout[:-1]
            relocated = replace_paths(rpath, old, new)
            for h in hits:
                if h['section'] == '.dynstr':
                    # Only a full colon-delimited RPATH component can own this
                    # occurrence. Every other dynamic use fails closed.
                    if h['string'] is None or h['string'].encode() != rpath or old not in rpath:
                        raise ValueError(('unsupported dynamic prefix', name, h))
                elif (h['section'] != '.rodata' or not h['readonlyAllocated']
                      or not h['prefixAtStringStart'] or h['stringEnd'] < 0
                      or not h['string'].encode().startswith(old+b'/lib/')):
                    raise ValueError(('unsupported compiled prefix', name, h))
                else:
                    a, b = h['stringStart'], h['stringEnd']
                    original = data[a:b]
                    replacement = replace_paths(original, old, new)
                    if len(original) != len(replacement):
                        raise ValueError('compiled width changed')
                    data = data[:a]+replacement+data[b:]
            changes[name] = data
            if rpath != relocated:
                dynamic[name] = relocated.decode()
        elif old in data:
            changes[name] = replace_paths(text(data, name), old, new)
        # Runtime Cwd binding belongs exclusively to finalization. Validate its
        # complete text before replacing the source preparation provider.
        if p.name == 'Cwd.pm' and config.get('externalPwd', False):
            original = changes.get(name, data)
            text(original, name)
            build = config['buildPwd'].encode(); runtime = config['runtimePwd'].encode()
            if original.count(build) != 5:
                raise ValueError(('installed Cwd provider count', name))
            if not os.path.isfile(runtime) or not os.access(runtime, os.X_OK):
                raise ValueError('missing runtime pwd')
            changes[name] = original.replace(build, runtime)
    for name, target in links.items():
        data = replace_paths(target.encode(), old, new)
        updated = data.decode()
        linkchanges[name] = updated
    # Resolve the planned namespace before any write, including aliases through
    # other relocated links. Do not trust resolve() against the old namespace.
    def resolve_link(name, active):
        if name in active:
            raise ValueError(('installed symlink cycle', name))
        target = linkchanges[name]
        if target.startswith('/'):
            if not target.startswith(str(root)+'/'):
                raise ValueError(('escaping absolute installed symlink', name))
            parts = list(Path(target).relative_to(root).parts)
        else:
            parts = list(Path(name).parent.parts) + list(Path(target).parts)
        result = []
        for part in parts:
            if part == '..':
                if not result:
                    raise ValueError(('escaping relative installed symlink', name))
                result.pop()
            elif part != '.':
                result.append(part)
                partial = '/'.join(result)
                if partial in linkchanges:
                    result = list(resolve_link(partial, active | {name}).parts)
        candidate = root.joinpath(*result)
        if not candidate.exists():
            raise ValueError(('dangling installed symlink', name))
        return Path(*result)
    for name in linkchanges:
        resolve_link(name, set())
    # Preflight complete. Internal hardlinks are updated once, deliberately
    # relinked after patchelf (which may replace an inode), with original mode.
    for group in groups:
        name = group[0]
        if name not in changes:
            continue
        p = files[name]; mode = stat.S_IMODE(p.stat().st_mode)
        try:
            p.chmod(mode | stat.S_IWUSR)
            with p.open('r+b') as f:
                f.write(changes[name]); f.truncate()
            if name in dynamic:
                subprocess.run([config['patchelf'], '--set-rpath', dynamic[name], str(p)], check=True, capture_output=True)
            for alias in group[1:]:
                files[alias].unlink(); os.link(p, files[alias])
        finally:
            p.chmod(mode)
    for name, target in linkchanges.items():
        if target != links[name]:
            p = root/name; p.unlink(); p.symlink_to(target)
    audit(str(root), [config['artifact']])
    return {'files': len(files), 'hardlinkGroups': [g for g in groups if len(g)>1],
            'elfMappings': mappings, 'relocatedFiles': sorted(changes), 'rpaths': dynamic,
            'equalWidth': len(old), 'artifactExcluded': True}


def audit(root, artifacts):
    root, files, groups, links = tree(root)
    for name, p in files.items():
        data = p.read_bytes()
        for artifact in artifacts:
            if artifact.encode() in data:
                raise ValueError(('artifact bytes remain', name, artifact))
    for name, target in links.items():
        if any(a in target for a in artifacts):
            raise ValueError(('artifact symlink remains', name))
        candidate = Path(target) if target.startswith('/') else (root/name).parent/target
        if not candidate.resolve(strict=True).is_relative_to(root):
            raise ValueError(('dangling/escaping final symlink', name))


if __name__ == '__main__':
    if sys.argv[1] == 'audit':
        audit(sys.argv[2], json.loads(sys.argv[3]))
    else:
        config = json.loads(sys.argv[1])
        config.update(root=sys.argv[2], artifact=sys.argv[3])
        print(json.dumps(finalize(config), sort_keys=True))
