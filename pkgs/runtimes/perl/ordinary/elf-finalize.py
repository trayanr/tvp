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


def exclusive_rpath(data, records, index):
    """Inventory every supported consumer of the dynamic string table.

    Patchelf can preserve a string used by another tag, symbol or version name.
    Refuse sharing, including suffix pointers, before the mutation phase.
    """
    table = records[index]
    if table[1] != 3 or table[2] & 7 != 2:
        raise ValueError('expected allocated readonly dynamic string table')
    strings = data[table[4]:table[4] + table[5]]
    consumers = []

    def consume(offset, role):
        if not 0 <= offset < len(strings):
            raise ValueError(('invalid dynamic string index', role, offset))
        end = strings.find(b'\0', offset)
        if end < 0:
            raise ValueError(('unterminated dynamic string', role))
        consumers.append((offset, end + 1, role))

    dynamics = [s for s in records if s[1] == 6]
    if len(dynamics) != 1 or dynamics[0][6] != index:
        raise ValueError('ambiguous dynamic/string table binding')
    dynamic = dynamics[0]
    if dynamic[9] != 16 or dynamic[5] % 16:
        raise ValueError('invalid dynamic entry layout')
    tags, terminated = {}, False
    string_tags = {1, 14, 15, 29, 0x6ffffefa, 0x6ffffefb, 0x6ffffefc,
                   0x7ffffffd, 0x7fffffff}
    value_tags = (set(range(31)) | set(range(32, 38))
                  | {0x6ffffef5, 0x6ffffff0, 0x6ffffff9, 0x6ffffffa,
                     0x6ffffffb, 0x6ffffffe, 0x6fffffff})
    for pos in range(dynamic[4], dynamic[4] + dynamic[5], 16):
        tag, value = struct.unpack_from('<qQ', data, pos)
        if terminated:
            if tag or value:
                raise ValueError('nonempty dynamic records after terminator')
            continue
        if tag == 0:
            terminated = True
        elif tag in string_tags:
            consume(value, 'rpath' if tag in (15, 29) else 'dynamic-tag-' + str(tag))
        elif tag not in value_tags:
            raise ValueError(('unsupported dynamic tag', tag))
        tags.setdefault(tag, []).append(value)
    if not terminated or tags.get(5) != [table[3]] or tags.get(10) != [table[5]]:
        raise ValueError('dynamic string address/size mismatch')

    # Bind section metadata to the ranges used by the loader as well.
    phoff = struct.unpack_from('<Q', data, 32)[0]
    phsize, phnum = struct.unpack_from('<HH', data, 54)
    if phsize != 56 or not phnum or phoff + phsize * phnum > len(data):
        raise ValueError('invalid program header table')
    programs = [struct.unpack_from('<IIQQQQQQ', data, phoff + phsize * i)
                for i in range(phnum)]
    if [(p[2], p[3], p[5]) for p in programs if p[0] == 2] != [
            (dynamic[4], dynamic[3], dynamic[5])]:
        raise ValueError('dynamic section/program range mismatch')
    def loaded(section):
        return any(p[0] == 1 and p[3] <= section[3]
                   and section[3] + section[5] <= p[3] + p[5]
                   and p[2] + section[3] - p[3] == section[4] for p in programs)

    if not loaded(table):
        raise ValueError('dynamic strings do not map to loader file range')

    symbol_tables, version_tables = 0, 0
    for section in records:
        if section[6] != index or section is dynamic:
            continue
        offset, size = section[4], section[5]
        if section[1] == 11:  # Elf64_Sym.st_name
            symbol_tables += 1
            if (section[9] != 24 or size % 24 or not loaded(section)
                    or tags.get(6) != [section[3]] or tags.get(11) != [24]):
                raise ValueError('invalid dynamic symbol table')
            for pos in range(offset, offset + size, 24):
                consume(struct.unpack_from('<I', data, pos)[0], 'symbol')
        elif section[1] == 0x6ffffffe:  # Elf64_Verneed / Elf64_Vernaux
            version_tables += 1
            if (not loaded(section) or tags.get(0x6ffffffe) != [section[3]]
                    or tags.get(0x6fffffff) != [section[7]]):
                raise ValueError('version-needed dynamic binding mismatch')
            pos, count, seen = 0, 0, set()

            def version_record(relative, layout):
                width = struct.calcsize(layout)
                if relative in seen or not 0 <= relative <= size - width:
                    raise ValueError('invalid/cyclic version-needed record')
                seen.add(relative)
                return struct.unpack_from(layout, data, offset + relative)

            while True:
                version, number, file, auxiliary, following = version_record(pos, '<HHIII')
                if version != 1 or not number or auxiliary < 16:
                    raise ValueError('invalid version-needed header')
                consume(file, 'version-file')
                aux = pos + auxiliary
                for i in range(number):
                    _, _, _, name, next_aux = version_record(aux, '<IHHII')
                    consume(name, 'version-name')
                    if (i == number - 1 and next_aux != 0) or (i < number - 1 and next_aux < 16):
                        raise ValueError('invalid version-needed auxiliary chain')
                    aux += next_aux
                count += 1
                if not following:
                    break
                if following < 16:
                    raise ValueError('invalid version-needed chain')
                pos += following
            if count != section[7]:
                raise ValueError('version-needed count mismatch')
        else:
            raise ValueError(('unsupported dynamic string consumer', section[1]))
    if symbol_tables != 1 or version_tables != int(0x6ffffffe in tags):
        raise ValueError('missing/ambiguous dynamic consumer table')

    paths = [c for c in consumers if c[2] == 'rpath']
    if len(paths) != 1:
        raise ValueError('expected exactly one RPATH/RUNPATH string')
    start, end, _ = paths[0]
    if any(a < end and start < b for a, b, role in consumers if role != 'rpath'):
        raise ValueError('RPATH shares dynamic string bytes with another consumer')
    return table[4] + start, table[4] + end - 1, strings[start:end - 1]


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
    dynamic_hits = [h for h in hits if h['section'] == '.dynstr']
    if dynamic_hits:
        indices = [i for i, s in enumerate(sections) if s[0] == '.dynstr']
        if len(indices) != 1:
            raise ValueError('ambiguous dynamic string section')
        begin, end, value = exclusive_rpath(data, records, indices[0])
        for h in dynamic_hits:
            if h['stringStart'] != begin or h['stringEnd'] != end:
                raise ValueError('dynamic prefix is not exclusively owned by RPATH')
            h['exclusiveRpath'] = value.decode('ascii')
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
        # Every pathname contributes its role, irrespective of which contained
        # hardlink is encountered first. One inode gets one coherent edit.
        metadata = any(Path(alias).name in ('Config.pm', 'Config_heavy.pl', '.packlist', 'config.sh')
                       or '/CORE/' in '/' + alias and Path(alias).suffix in ('.h', '.c', '.inc')
                       for alias in group)
        cwd = any(Path(alias).name == 'Cwd.pm' for alias in group)
        if metadata and cwd:
            raise ValueError(('conflicting metadata/Cwd hardlink roles', group))
        if metadata or cwd:
            text(data, group)  # Corrupt metadata never selects binary routing.
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
                    if h.get('exclusiveRpath') is None or h['exclusiveRpath'].encode() != rpath or old not in rpath:
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
        if cwd and config.get('externalPwd', False):
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
