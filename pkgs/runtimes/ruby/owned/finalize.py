"""Ruby's compiled paths and installed data around reviewed ELF finalization.

Only lib/libruby-static.a, GNU ar, native non-LTO ELF64 objects and allocated,
readonly .rodata path strings are supported. Equal-width replacements preserve
object/relocation offsets. All members are inspected before ar writes a private
archive. No production source, compiler invocation or build tree is needed.
Installed relocatable gem objects are preserved around the dynamic-ELF pass.
"""
from pathlib import Path
import importlib.util
import json
import os
import re
import stat
import struct
import subprocess
import sys
import tempfile


def run(*args):
    result = subprocess.run(args, check=True, capture_output=True)
    if result.stderr:
        raise ValueError(('tool diagnostics', args[0], result.stderr))
    return result.stdout


def object_paths(data, old, new):
    if len(old) != len(new) or old == new:
        raise ValueError('distinct equal-width prefixes required')
    if len(data) < 64 or data[:7] != b'\x7fELF\x02\x01\x01':
        raise ValueError('expected native ELF64 archive member')
    kind, machine, version = struct.unpack_from('<HHI', data, 16)
    shoff = struct.unpack_from('<Q', data, 40)[0]
    ehsize, _, phnum, shsize, shnum, names = struct.unpack_from('<HHHHHH', data, 52)
    if (kind != 1 or machine != 62 or version != 1 or ehsize != 64 or phnum
            or shsize != 64 or not 0 < names < shnum or shoff < 64
            or shoff + 64 * shnum > len(data)):
        raise ValueError('expected native ET_REL with ordinary sections')
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + 64*i) for i in range(shnum)]
    table = sections[names]
    if table[1] != 3:
        raise ValueError('expected section names')
    for section in sections:
        if section[1] != 8 and section[4] + section[5] > len(data):
            raise ValueError('truncated object section')
    strings = data[table[4]:table[4]+table[5]]
    named = []
    for section in sections:
        i = section[0]; end = strings.find(b'\0', i)
        if i >= len(strings) or end < 0:
            raise ValueError('invalid section name')
        name = strings[i:end]
        if name.startswith(b'.gnu.lto_') or name in (b'.llvm.lto', b'.llvmbc'):
            raise ValueError('LTO Ruby archive outside this contract')
        named.append((name, section))
    start = 0
    while True:
        hit = data.find(old, start)
        if hit < 0:
            break
        owners = [(n, s) for n, s in named if s[1] != 8 and s[4] <= hit and hit+len(old) < s[4]+s[5]]
        if len(owners) != 1:
            raise ValueError('ambiguous archive prefix owner')
        name, section = owners[0]
        end = data.find(b'\0', hit, section[4]+section[5])
        if (not (name == b'.rodata' or name.startswith(b'.rodata.str'))
                or section[1] != 1 or section[2] & 7 != 2
                or (hit != section[4] and data[hit-1] != 0) or end < 0
                or data[hit+len(old):hit+len(old)+1] not in (b'/', b'\0')):
            raise ValueError(('unsupported Ruby static path string', name, hit))
        data = data[:hit] + new + data[hit+len(old):]
        start = hit + len(new)
    return data


def compiled_paths(data, hits, old, new):
    """Relocate Ruby's root and path constants in readonly ELF strings."""
    if len(old) != len(new) or old == new:
        raise ValueError('distinct equal-width prefixes required')
    for hit in hits:
        if hit['section'] == '.dynstr':
            continue
        start, end = hit['stringStart'], hit['stringEnd']
        if (not (hit['section'] == '.rodata' or hit['section'].startswith('.rodata.str'))
                or not hit['readonlyAllocated']
                or not hit['prefixAtStringStart'] or end < 0
                or data[start:start+len(old)] != old or data[end:end+1] != b'\0'
                or data[start+len(old):start+len(old)+1] not in (b'/', b'\0')):
            raise ValueError('unsupported Ruby compiled path string')
        data = data[:start] + new + data[start+len(old):]
    return data


def replace_paths(data, old, new):
    """Ruby's installed Makefiles also embed paths in -I/-L/-R options."""
    allowed = b"/\x00\n\r\t '\";:),]}<>"
    start = 0
    while True:
        pos = data.find(old, start)
        if pos < 0:
            break
        end = pos + len(old)
        option = (pos >= 2 and data[pos-2:pos] in (b'-I', b'-L', b'-R')
                  and (pos == 2 or data[pos-3] in b" \t\r\n'\"=,:("))
        if ((pos and (chr(data[pos-1]).isalnum() or data[pos-1] in b'/_+-.') and not option)
                or (end < len(data) and data[end] not in allowed)):
            raise ValueError(('non-path Ruby prefix occurrence', pos))
        start = end
    return data.replace(old, new)


def relocate_compiled_paths(files, groups, old, new, inspector, readelf):
    planned = []
    for group in groups:
        path = files[group[0]]
        with path.open('rb') as source:
            if source.read(4) != b'\x7fELF':
                continue
            source.seek(0)
            data = source.read()
        if old not in data:
            continue
        if len(data) >= 18 and struct.unpack_from('<H', data, 16)[0] == 1:
            continue
        changed = compiled_paths(data, inspector(path, old, readelf), old, new)
        if changed != data:
            planned.append((path, changed, path.stat()))
    for path, data, info in planned:
        path.write_bytes(data)
        os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))


def relocatable_objects(files, groups, old, new):
    preserved = []
    for group in groups:
        path = files[group[0]]
        with path.open('rb') as source:
            header = source.read(18)
            if not header.startswith(b'\x7fELF') or len(header) < 18 or header[16:18] != b'\x01\x00':
                continue
            source.seek(0)
            data = source.read()
        # Unchanged object payloads need no dynamic-loader operation. Objects
        # containing this prefix use the same bounded repair as static members.
        changed = object_paths(data, old, new) if old in data else data
        preserved.append((path, changed, path.stat()))
    return preserved


def relocate_archive(path, old, new, ar, readelf, directory):
    if path.is_symlink() or not stat.S_ISREG(path.stat().st_mode) or path.stat().st_nlink != 1:
        raise ValueError('expected unlinked installed Ruby static archive')
    if path.read_bytes()[:8] != b'!<arch>\n':
        raise ValueError('expected normal GNU Ruby static archive')
    run(readelf, '-W', '-h', '-S', str(path))
    names = run(ar, 't', str(path)).decode().splitlines()
    if (not names or len(names) != len(set(names))
            or any(not re.fullmatch(r'[A-Za-z0-9_+.-]+\.o', n) for n in names)):
        raise ValueError('unsupported/duplicate Ruby object member names')
    # Inspect the complete archive before materializing any updated member.
    members = [(n, object_paths(run(ar, 'p', str(path), n), old, new)) for n in names]
    target = directory / path.name
    target.write_bytes(path.read_bytes())
    for name, data in members:
        original = run(ar, 'p', str(path), name)
        if data != original:
            member = directory / name
            member.write_bytes(data)
            run(ar, 'rD', str(target), str(member))
    run(ar, 'sD', str(target))
    run(readelf, '-W', '-h', '-S', str(target))
    if old in target.read_bytes():
        raise ValueError('artifact bytes remain in Ruby static archive')
    return target


def main():
    config = json.loads(sys.argv[1])
    root, artifact, shared = sys.argv[2:5]
    loader = importlib.util.spec_from_file_location('reviewed_elf_finalizer', shared)
    module = importlib.util.module_from_spec(loader)
    loader.loader.exec_module(module)
    # Select Ruby's supported text/option forms only in this private module;
    # the shared Perl procedure and its callers retain their original policy.
    module.replace_paths = replace_paths
    # The reviewed walker validates the complete installed namespace first.
    _, files, groups, _ = module.tree(root)
    relocate_compiled_paths(files, groups, artifact.encode(), root.encode(),
                           module.inspect, config['readelf'])
    objects = relocatable_objects(files, groups, artifact.encode(), root.encode())
    archive = Path(root) / 'lib/libruby-static.a'
    config.update(root=root, artifact=artifact)
    with tempfile.TemporaryDirectory(prefix='ruby-static-') as work:
        staged = None
        if archive.exists() or archive.is_symlink():
            staged = relocate_archive(archive, artifact.encode(), root.encode(),
                                      config['ar'], config['readelf'], Path(work))
            info = archive.stat()
        # Keep object names/inodes (and aliases) in the namespace while the
        # Perl-specific walker processes dynamic ELF and text. Restore the
        # actual object bytes before the authoritative final reference audit.
        for path, _, _ in objects:
            path.write_bytes(b'')
        if staged:
            archive.unlink()
        try:
            module.finalize(config)
        finally:
            if staged:
                archive.write_bytes(staged.read_bytes())
                archive.chmod(stat.S_IMODE(info.st_mode))
                os.utime(archive, ns=(info.st_atime_ns, info.st_mtime_ns))
            for path, data, state in objects:
                path.write_bytes(data)
                path.chmod(stat.S_IMODE(state.st_mode))
                os.utime(path, ns=(state.st_atime_ns, state.st_mtime_ns))
        module.audit(root, [artifact])


if __name__ == '__main__':
    main()
