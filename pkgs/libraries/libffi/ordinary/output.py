"""Relocate installed prefix slots; validate the entire tree before any writes.

ELF prefix replacements keep their length by adding redundant directory separators.
Installed helper interpreters and embedded shell defaults are selected together.
"""
import json
import re
import shlex
import os
from pathlib import Path
import stat
import struct
import sys
import subprocess
from collections import Counter

root = Path(sys.argv[1])
if root.is_symlink():
    raise ValueError('output root must not be a symlink')
root = root.resolve(strict=True)
old = os.fsencode(sys.argv[2])
new = os.fsencode(str(root))
config = json.loads(sys.argv[4])
assert len(new) <= len(old)
changes = []
link_changes = []
rpaths = []
inodes = Counter()
links = {}
patchelf = sys.argv[3]

def inspect(binary, *arguments):
    if not os.path.isabs(binary):
        raise ValueError(('expected absolute selected inspection tool', binary))
    result = subprocess.run([binary, *[os.fspath(a) if isinstance(a, (str, bytes, os.PathLike)) else str(a) for a in arguments]], capture_output=True,
                            env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode or result.stderr:
        raise ValueError(('ELF inspection failed', binary, result.returncode,
                          result.stderr.decode(errors='replace')))
    return result.stdout

def dynamic_elf(path, data):
    if len(data) < 64 or data[4:7] != b'\x02\x01\x01':
        raise ValueError(('expected native ELF64 little-endian', path))
    kind, machine, version = struct.unpack_from('<HHI', data, 16)
    if kind not in (1, 2, 3) or machine != 62 or version != 1:
        raise ValueError(('unsupported native ELF', path))
    headers = inspect(config['readelf'], '--wide', '--file-header',
                      '--program-headers', '--section-headers', path)
    if not (headers.startswith(b'ELF Header:') and
            re.search(rb'Class:\s+ELF64\b', headers) and
            re.search(rb'Machine:\s+Advanced Micro Devices X86-64', headers)):
        raise ValueError(('malformed selected ELF inspection', path))
    phoff = struct.unpack_from('<Q', data, 32)[0]
    shoff = struct.unpack_from('<Q', data, 40)[0]
    ehsize, phsize, phnum, shsize, shnum = struct.unpack_from('<HHHHH', data, 52)
    if ehsize != 64:
        raise ValueError(('invalid ELF header size', path))
    dynamic = interpreter = False
    if kind == 1:
        if phnum or shsize != 64 or not shnum or shoff < 64 or shoff + shsize * shnum > len(data):
            raise ValueError(('invalid relocatable ELF tables', path))
        for offset in range(shoff, shoff + shsize * shnum, shsize):
            section = struct.unpack_from('<IIQQQQIIQQ', data, offset)
            if section[1] != 8 and section[4] + section[5] > len(data):
                raise ValueError(('truncated relocatable section', path))
    else:
        if phsize != 56 or not phnum or phnum == 65535 or phoff < 64 or phoff + phsize * phnum > len(data):
            raise ValueError(('invalid ELF program headers', path))
        for offset in range(phoff, phoff + phsize * phnum, phsize):
            tag, _, fileoffset, _, _, length = struct.unpack_from('<IIQQQQ', data, offset)
            if fileoffset + length > len(data):
                raise ValueError(('truncated ELF segment', path))
            dynamic |= tag == 2
            interpreter |= tag == 3
    if interpreter and not dynamic:
        raise ValueError(('ELF interpreter without dynamic segment', path))
    return dynamic

# Validate every selected parent and leaf before staging any replacement.
library64 = config.get('library64', False)
library_moves = []
if library64:
    for directory in ('lib', 'lib64'):
        path = root / directory
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode):
            raise ValueError(('library layout needs real directories', path))
    for path in (root / 'lib64').iterdir():
        if not re.fullmatch(r'libffi\.(?:a|la|so(?:\.[0-9]+)*)', path.name):
            raise ValueError(('unexpected multi-os library', path))
        destination = root / 'lib' / path.name
        if os.path.lexists(destination):
            raise ValueError(('multi-os library collision', destination))
        library_moves.append((path, destination))
    if not library_moves:
        raise ValueError('empty multi-os library directory')

for kind, selectors in [('directory', config.get('requiredDirectories', [])),
                        ('file', config.get('requiredFiles', []))]:
    for selector in selectors:
        if library64 and re.fullmatch(r'lib/libffi\.(?:a|la)', selector):
            selector = selector.replace('lib/', 'lib64/', 1)
        parts = selector.split('/')
        if not selector or any(part in ('', '.', '..') for part in parts):
            raise ValueError(('unsafe required output selector', selector))
        path = root
        for index, part in enumerate(parts):
            path = path / part
            info = path.lstat()
            directory = index < len(parts) - 1 or kind == 'directory'
            if (stat.S_ISLNK(info.st_mode) or
                    not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))):
                raise ValueError(('invalid required output target', path, kind))

for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        p = Path(directory) / name
        st = p.lstat()
        if stat.S_ISLNK(st.st_mode):
            raw = os.readlink(p)
            if str(p.relative_to(root)) in config['requiredRegular']:
                raise ValueError(('selected metadata/archive alias', p))
            if p.is_relative_to(root/'share/man') and not p.name.endswith('.gz') and os.path.lexists(str(p)+'.gz'):
                raise ValueError(('manual alias compression collision', p))
            if p.is_dir():
                # Upstream's documented compatibility view of the installed database.
                if p == root / 'lib/terminfo' and raw == '../share/terminfo' and (root / 'share/terminfo').is_dir() and not (root / 'share/terminfo').is_symlink():
                    continue
                raise ValueError(('directory alias', p))
            if raw.startswith(os.fsdecode(old) + '/'):
                target = root / raw[len(os.fsdecode(old)) + 1:]
                assert target.resolve(strict=True).is_relative_to(root), ('escaping self alias', p)
                link_changes.append((p, os.path.relpath(target, p.parent)))
            else:
                target = p.resolve(strict=True)
                assert target.is_relative_to(root), ('escaping symlink', p)
                assert not os.path.isabs(raw), ('absolute symlink', p)
            # Public executable aliases cannot hide a script outside the
            # frontend selection. Library aliases to native ELF stay valid.
            if any(p.is_relative_to(root / area) for area in ('bin', 'lib', 'libexec')):
                target = target.resolve(strict=True)
                target_info = target.stat()
                if not stat.S_ISREG(target_info.st_mode):
                    raise ValueError(('special executable alias target', p, target))
                data = target.read_bytes()
                if not data.startswith(b'\x7fELF') and (data.startswith(b'#!') or target_info.st_mode & 0o111):
                    raise ValueError(('selected executable alias', p, target))
        elif stat.S_ISREG(st.st_mode):
            inode = (st.st_dev, st.st_ino)
            inodes[inode] += 1
            links[inode] = st.st_nlink
            data = p.read_bytes()
            executable_area = any(p.is_relative_to(root / name) for name in ('bin', 'lib', 'libexec'))
            if executable_area and data.startswith(b'#!') and b'\0' in data:
                raise ValueError(('NUL in installed script', p))
            libtool_data = str(p.relative_to(root)).replace('lib64/', 'lib/', 1) in config.get('libtoolData', [])
            if libtool_data and (b'\0' in data or not data.startswith(b'# ' + p.name.encode() + b' - a libtool library file\n')):
                raise ValueError(('invalid libtool metadata', p))
            if executable_area and not libtool_data and st.st_mode & 0o111 and not data.startswith((b'#!', b'\x7fELF')):
                raise ValueError(('unsupported executable frontend', p))
            if p.is_relative_to(root/'share/man') and not p.name.endswith('.gz') and os.path.lexists(str(p)+'.gz'):
                raise ValueError(('manual compression collision', p))
            if data.startswith(b'\x7fELF'):
                if dynamic_elf(p, data):
                    raw = inspect(patchelf, '--print-rpath', p).removesuffix(b'\n')
                    if any(c in raw for c in (b'\0', b'\r', b'\n')):
                        raise ValueError(('malformed selected RPATH inspection', p))
                    relocated = raw.replace(old, new)
                    if relocated != raw:
                        rpaths.append((p, relocated))
            if data.startswith(b'\x7fELF') or b'\0' in data:
                replaced = data.replace(old, new + b'/' * (len(old) - len(new)))
            else:
                replaced = data.replace(old, new)
                if replaced.startswith(b'#!') and any(p.is_relative_to(root / name) for name in ('bin', 'lib', 'libexec')):
                    first, body = replaced.split(b'\n', 1)
                    shell = re.fullmatch(rb'#![ \t]*/(?:[^ \t\n]+/)*(?:sh|bash)(?: (-e|-))?', first)
                    awk = re.fullmatch(rb'#![ \t]*/(?:[^ \t\n]+/)*(?:awk|gawk)([ \t]+-[Mf]+)?', first)
                    if shell:
                        body = body.replace(config['buildShell'].encode(), config['shell'].encode())
                        # Match complete literal pathnames, so rebinding /bin/bash
                        # cannot rewrite the suffix of an already selected store path.
                        body = re.sub(rb'(?<![A-Za-z0-9_./])/(?:[A-Za-z0-9_.+-]+/)*(?:sh|bash)(?![A-Za-z0-9_./+-])',
                                      lambda m: config['shell'].encode() if m[0] in {
                                          b'/bin/sh', b'/bin/bash', b'/usr/bin/sh', b'/usr/bin/bash'
                                      } else m[0], body)
                        preamble = ('PATH=' + shlex.quote(str(root/'bin') + ':' + ':'.join(config['paths']))
                                    + ':"${PATH-}"\nexport PATH\nSHELL=' + shlex.quote(config['shell']) + '\nexport SHELL\n').encode()
                        replaced = b'#!' + config['shell'].encode() + (b' '+shell[1] if shell[1] else b'') + b'\n' + preamble + body
                    else:
                        raise ValueError(('unexpected installed frontend', p, first))
            requirement = config.get('pkgConfigRequires', {}).get(str(p.relative_to(root)))
            if requirement:
                pattern = rb'^Requires\.private: ' + re.escape(requirement['before'].encode()) + rb'$'
                replaced, count = re.subn(pattern, b'Requires.private: ' + requirement['after'].encode(), replaced, flags=re.MULTILINE)
                if count != 1:
                    raise ValueError(('pkg-config provider anchor', p, count))
            assert old not in replaced, p
            if replaced != data or st.st_nlink > 1 or libtool_data:
                changes.append((p, replaced, stat.S_IMODE(st.st_mode) & (~0o111 if libtool_data else 0o7777)))
        elif not stat.S_ISDIR(st.st_mode):
            raise ValueError(('special file', p))
assert all(inodes[k] == n for k, n in links.items()), 'hardlink escapes output'
for p, target in link_changes:
    assert not os.path.lexists(str(p) + '.tvp-relocating'), ('alias collision', p)
for p, data, mode in changes:
    tmp = p.with_name(p.name + '.tvp-relocating')
    assert not tmp.exists() and not tmp.is_symlink(), tmp
for p, data, mode in changes:
    tmp = p.with_name(p.name + '.tvp-relocating')
    assert not tmp.exists() and not tmp.is_symlink(), tmp
    with tmp.open('xb') as stream:
        stream.write(data)
    tmp.chmod(mode)
    tmp.replace(p)
for p, target in link_changes:
    temp = p.with_name(p.name + '.tvp-relocating')
    temp.symlink_to(target)
    temp.replace(p)
# Repair only artifact-prefix substitutions recorded before the fixed-width copy.
# Preserve loader tokens, symlink-sensitive '..', empty entries and user spelling.
for p, rpath in rpaths:
    if inspect(patchelf, '--set-rpath', rpath, p):
        raise ValueError(('unexpected patchelf mutation output', p))
for path, destination in library_moves:
    os.replace(path, destination)
if library64:
    (root / 'lib64').rmdir()
    (root / 'lib64').symlink_to('lib')
print('relocated', len(changes), 'installed files')
