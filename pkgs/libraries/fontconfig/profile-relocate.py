"""Exact Fontconfig 2.18.3 config/cache/template slots, after tree preflight.

Reuse the established native ELF ownership inspector and path/tree guards.
Only source-defined readonly strings, a verified inlined config-path copy,
and exclusively owned RPATH slots may change in native payloads. Unknown emitted layouts fail closed and
remain a later qualification requirement. No static archive or cache rewriting.
"""
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import struct
import sys


def config_vector_owned(block, old, address, listing):
    """Pinned x86_64 FcConfigGetFilename strcpy lowering: 64 bytes plus tail."""
    if len(old) != 61 or block != old + b'/et' or '<FcConfigGetFilename>:' not in listing:
        return False
    instructions = [m[1] for line in listing.splitlines()
                    if (m := re.match(r'^\s*[0-9a-f]+:\s+(.+)$', line))]
    for start in range(len(instructions) - 11):
        window = instructions[start:start + 12]
        for index, position in enumerate((0, 6, 8, 10)):
            match = re.fullmatch(r'movdqa\s+0x[0-9a-f]+\(%rip\),%xmm0\s+#\s+([0-9a-f]+).*', window[position])
            if not match or int(match[1], 16) != address + 16 * index:
                break
        else:
            normalized = [''.join(line.split()) for line in window]
            expected = {1: 'mov(%r15),%rbp', 2: 'xor%ebx,%ebx',
                        3: 'movabs$0x73746e6f662f63,%rcx', 4: 'mov%rcx,0x40(%rax)',
                        5: 'movups%xmm0,(%rax)', 7: 'movups%xmm0,0x10(%rax)',
                        9: 'movups%xmm0,0x20(%rax)', 11: 'movups%xmm0,0x30(%rax)'}
            if all(normalized[i] == value for i, value in expected.items()):
                return True
    return False


def finalize(root, artifact, readelf, patchelf, elf, objdump=None):
    root, files, groups, links = elf.tree(root)
    old, new = os.fsencode(artifact), os.fsencode(root)
    if (old == new or len(old) != len(new)
            or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+', old)):
        raise ValueError('distinct equal-width store prefixes required')
    for tool in (readelf, patchelf) + ((objdump,) if objdump is not None else ()):
        if not tool.startswith('/nix/store/') or not os.path.isfile(tool) or not os.access(tool, os.X_OK):
            raise ValueError('explicit executable store inspection tools required')
    constants = {old + p for p in (
        b'/etc/fonts', b'/etc/fonts/conf.d', b'/share/fontconfig/conf.avail',
        b'/var/cache/fontconfig')}
    # fcinit.c's source-defined fallback XML is one complete readonly string.
    # Keep every directory, attribute and whitespace byte pinned to this profile.
    fallback = (
        b'<fontconfig>\t<dir>/usr/share/fonts</dir>\n'
        b'\t<dir>/usr/local/share/fonts</dir>\n'
        b'  <dir prefix="xdg">fonts</dir>'
        b'  <cachedir>' + old + b'/var/cache/fontconfig</cachedir>'
        b'  <cachedir prefix="xdg">fontconfig</cachedir>'
        b'  <include ignore_missing="yes">' + old + b'/etc/fonts/conf.d</include>'
        b'  <include ignore_missing="yes" prefix="xdg">fontconfig/conf.d</include>'
        b'  <include ignore_missing="yes" prefix="xdg">fontconfig/fonts.conf</include>'
        b'</fontconfig>')
    changes, dynamics, aliases = {}, {}, {}
    for group in groups:
        name = group[0]
        path = files[name]
        data = path.read_bytes()
        if old not in data:
            continue
        if data.startswith(b'\x7fELF'):
            if not all(n.startswith('bin/fc-') or re.fullmatch(r'lib/libfontconfig\.so\.[0-9.]+', n) for n in group):
                raise ValueError(('unexpected native Fontconfig role', group))
            hits = elf.inspect(path, old, readelf)
            updated = data
            for hit in hits:
                if hit['section'] == '.dynstr':
                    raw = hit.get('exclusiveRpath')
                    if raw is None:
                        raise ValueError('unowned dynamic string')
                    dynamics[name] = elf.replace_paths(raw.encode(), old, new).decode()
                elif (not hit['section'].startswith('.rodata') or not hit['readonlyAllocated']
                      or hit['stringEnd'] < 0):
                    raise ValueError(('unsupported compiled Fontconfig slot', name, hit))
                else:
                    a, b = hit['stringStart'], hit['stringEnd']
                    value = data[a:b]
                    known_fallback = value == fallback and all(
                        re.fullmatch(r'lib/libfontconfig\.so\.[0-9.]+', n) for n in group)
                    if value not in constants and not known_fallback:
                        # fccfg.c strcpy(FONTCONFIG_PATH) is emitted as a 64-byte
                        # SIMD block plus an immediate c/fonts\0 tail. It is not
                        # a standalone /et path string; verify its reconstruction.
                        offset = hit['offset']
                        if not objdump or not all(re.fullmatch(r'lib/libfontconfig\.so\.[0-9.]+', n) for n in group):
                            raise ValueError(('unknown Fontconfig constant', name, value))
                        shoff = struct.unpack_from('<Q', data, 40)[0]
                        count = struct.unpack_from('<H', data, 60)[0]
                        sections = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + 64 * i) for i in range(count)]
                        owners = [s for s in sections if s[1] != 8 and s[4] <= offset and offset + 64 <= s[4] + s[5]]
                        listing = subprocess.run([objdump, '-d', '--no-show-raw-insn',
                                                  '--disassemble=FcConfigGetFilename', str(path)],
                                                 capture_output=True, text=True, check=True)
                        if (len(owners) != 1 or listing.stderr or a != offset
                                or not config_vector_owned(data[offset:offset + 64], old,
                                                           owners[0][3] + offset - owners[0][4], listing.stdout)):
                            raise ValueError(('unverified Fontconfig config-path block', name, offset))
                        a, b = offset, offset + 64
                    updated = updated[:a] + data[a:b].replace(old, new) + updated[b:]
            changes[name] = updated
        else:
            if not all(n == 'lib/pkgconfig/fontconfig.pc' or n.startswith((
                    'etc/fonts/', 'share/fontconfig/', 'share/man/',
                    'share/doc/', 'share/xml/', 'share/gettext/')) for n in group):
                raise ValueError(('unexpected self-referencing text role', group))
            changes[name] = elf.replace_paths(elf.text(data, name), old, new)
    for name, target in links.items():
        target = elf.replace_paths(os.fsencode(target), old, new).decode()
        resolved = (files.get(name, root / name).parent / target).resolve(strict=False)
        if not resolved.is_relative_to(root):
            raise ValueError(('escaping installed alias', name, target))
        aliases[name] = target
    # Every input and slot is inspected before the first write. Preserve hardlinks.
    for name, data in changes.items():
        path = files[name]
        info = path.stat()
        with path.open('r+b') as stream:
            stream.write(data)
            stream.truncate()
        os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
    for name, target in aliases.items():
        path = root / name
        if os.readlink(path) != target:
            path.unlink()
            path.symlink_to(target)
    for name, value in dynamics.items():
        subprocess.run([patchelf, '--set-rpath', value, str(files[name])], check=True)
    for path in files.values():
        if old in path.read_bytes():
            raise ValueError(('unrelocated Fontconfig prefix', path))


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('fontconfig_elf', sys.argv[5])
    elf = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(elf)
    finalize(*sys.argv[1:5], elf, sys.argv[6] if len(sys.argv) > 6 else None)
