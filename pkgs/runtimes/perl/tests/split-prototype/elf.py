"""Read-only native ELF prefix inventory for the split design experiment.

No generic binary replacement capability is provided. Report section/offset,
string boundaries and flags. The separate experiment may patch its disposable
fixture copies only, and must independently check the resulting behavior.
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
