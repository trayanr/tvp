"""Guarded equal-width libxml2 finalization (ELF inspector adapted from ordinary Perl), x86_64 ELF64 only.

Plan the whole tree before writes. Compiled library path slots are inspected as
complete NUL-delimited strings in allocated readonly .rodata. The family caller
validates their source-defined path, URI or help-message shape. Equal widths preserve all string
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
                     0x6ffffffb, 0x6ffffffc, 0x6ffffffd,
                     0x6ffffffe, 0x6fffffff})
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

    symbol_tables, version_tables, definition_tables = 0, 0, 0
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
        elif section[1] == 0x6ffffffd:  # Elf64_Verdef / Elf64_Verdaux
            definition_tables += 1
            if (not loaded(section) or tags.get(0x6ffffffc) != [section[3]]
                    or tags.get(0x6ffffffd) != [section[7]]):
                raise ValueError('version-definition dynamic binding mismatch')
            pos, count, seen = 0, 0, set()

            def definition_record(relative, layout):
                width = struct.calcsize(layout)
                if relative in seen or not 0 <= relative <= size - width:
                    raise ValueError('invalid/cyclic version-definition record')
                seen.add(relative)
                return struct.unpack_from(layout, data, offset + relative)

            while True:
                version, _, _, number, _, auxiliary, following = definition_record(pos, '<HHHHIII')
                if version != 1 or not number or auxiliary < 20:
                    raise ValueError('invalid version-definition header')
                aux = pos + auxiliary
                for i in range(number):
                    name, next_aux = definition_record(aux, '<II')
                    consume(name, 'version-definition-name')
                    if (i == number - 1 and next_aux != 0) or (i < number - 1 and next_aux < 8):
                        raise ValueError('invalid version-definition auxiliary chain')
                    aux += next_aux
                count += 1
                if not following:
                    break
                if following < 20:
                    raise ValueError('invalid version-definition chain')
                pos += following
            if count != section[7]:
                raise ValueError('version-definition count mismatch')
        else:
            raise ValueError(('unsupported dynamic string consumer', section[1]))
    if symbol_tables != 1 or version_tables != int(0x6ffffffe in tags):
        raise ValueError('missing/ambiguous dynamic consumer table')
    if (definition_tables != int(0x6ffffffc in tags)
            or (0x6ffffffc in tags) != (0x6ffffffd in tags)):
        raise ValueError('missing/ambiguous version-definition table')

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
    if kind not in (1, 2, 3) or machine != 62 or version != 1:
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
