"""Exact Fontconfig 2.18.3 config/cache/template slots, after tree preflight.

Reuse the established native ELF ownership inspector and path/tree guards.
Only complete source-defined readonly constants and exclusively owned RPATH
slots may change in native payloads. Unknown emitted layouts fail closed and
remain a later qualification requirement. No static archive or cache rewriting.
"""
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys


def finalize(root, artifact, readelf, patchelf, elf):
    root, files, groups, links = elf.tree(root)
    old, new = os.fsencode(artifact), os.fsencode(root)
    if (old == new or len(old) != len(new)
            or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+', old)):
        raise ValueError('distinct equal-width store prefixes required')
    for tool in (readelf, patchelf):
        if not tool.startswith('/nix/store/') or not os.path.isfile(tool) or not os.access(tool, os.X_OK):
            raise ValueError('explicit executable store inspection tools required')
    constants = {old + p for p in (
        b'/etc/fonts', b'/etc/fonts/conf.d', b'/share/fontconfig/conf.avail',
        b'/var/cache/fontconfig')}
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
                    if data[a:b] not in constants:
                        raise ValueError(('unknown Fontconfig constant', name, data[a:b]))
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
    finalize(*sys.argv[1:5], elf)
