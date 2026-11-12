"""Ruby's historical installed static archive around reviewed ELF finalization.

Only lib/libruby-static.a, GNU ar, native non-LTO ELF64 objects and allocated,
readonly .rodata path strings are supported. Equal-width replacements preserve
object/relocation offsets. All members are inspected before ar writes a private
archive. No production source, compiler invocation or build tree is needed.
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
    # The reviewed walker validates the complete installed namespace first.
    module.tree(root)
    archive = Path(root) / 'lib/libruby-static.a'
    config.update(root=root, artifact=artifact)
    if not archive.exists() and not archive.is_symlink():
        module.finalize(config)
        return
    with tempfile.TemporaryDirectory(prefix='ruby-static-') as work:
        staged = relocate_archive(archive, artifact.encode(), root.encode(),
                                  config['ar'], config['readelf'], Path(work))
        info = archive.stat()
        # The reviewed ELF/text procedure must not route an ar file as text.
        archive.unlink()
        module.finalize(config)
        archive.write_bytes(staged.read_bytes())
        archive.chmod(stat.S_IMODE(info.st_mode))
        os.utime(archive, ns=(info.st_atime_ns, info.st_mtime_ns))
        module.audit(root, [artifact])


if __name__ == '__main__':
    main()
