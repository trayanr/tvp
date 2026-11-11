"""OpenSSL final-only equal-width relocation and installed frontend binding.

Reuse the reviewed ELF/namespace inspectors, not a peer's recipe/finalizer.
Every input, hardlink role, compiled occurrence and planned link is checked
before any write. Complete raw upstream evidence remains in the artifact only.
"""
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import sys




def load(path):
    spec = importlib.util.spec_from_file_location('inspector', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def role(name):
    if name in ('nix-support/upstream.raw', 'nix-support/upstream.exit'):
        return 'evidence'
    if name == 'bin/c_rehash':
        return 'rehash'
    if (name.endswith(('.la', '.pc', '.cmake', '.h'))
            or name in ('include', 'lib/pkgconfig', 'lib/cmake', 'etc')
            or name.startswith(('include/', 'lib/pkgconfig/', 'lib/cmake/', 'etc/'))):
        return 'text'
    return 'ordinary'


def link_plan(root, files, links, old, new, replace_paths):
    """Resolve raw target components against the complete planned namespace."""
    directories = {''}
    for parent, names, _ in os.walk(root, followlinks=False):
        for name in names:
            path = Path(parent) / name
            if stat.S_ISDIR(path.lstat().st_mode):
                directories.add(path.relative_to(root).as_posix())
    planned = {name: replace_paths(value.encode(), old, new).decode()
               for name, value in links.items()}
    for name in planned:
        if role(name) != 'ordinary':
            raise ValueError(('unsupported installed semantic alias', name))
        pending, current, followed = name.split('/'), [], 0
        while pending:
            part = pending.pop(0)
            if part in ('', '.'):
                continue
            if part == '..':
                if not current:
                    raise ValueError(('escaping installed link', name))
                current.pop()
                continue
            candidate = '/'.join(current + [part])
            if candidate in planned:
                followed += 1
                if followed > 40:
                    raise ValueError(('cyclic or excessive installed link chain', name))
                target = planned[candidate]
                if target.startswith('/'):
                    if not target.startswith(str(root) + '/'):
                        raise ValueError(('outside installed link', name))
                    target, current = target[len(str(root)) + 1:], []
                # Keep empty and dot components: file/ and file/.. both
                # require an actual directory, just as kernel resolution does.
                pending = target.split('/') + pending
                continue
            if candidate not in files and candidate not in directories:
                raise ValueError(('missing installed link component', name, candidate))
            if pending and candidate not in directories:
                raise ValueError(('non-directory installed link component', name, candidate))
            current.append(part)
        final = '/'.join(current)
        if role(final) == 'evidence':
            raise ValueError(('alias to removed evidence', name))
        if name.startswith(('bin/', 'libexec/')):
            if (final not in files or not files[final].stat().st_mode & 0o111
                    or not files[final].read_bytes().startswith((b'\x7fELF', b'#!'))):
                raise ValueError(('unsupported public frontend alias', name))
    return planned


def finalize(helper, root, artifact, config, relocate_archive, inspect_elf):
    root, files, groups, links = helper.tree(root)
    old, new = artifact.encode(), str(root).encode()
    if (old == new or len(old) != len(new)
            or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+', old)):
        raise ValueError('distinct equal-width store prefixes required')
    for name in ['readelf', 'patchelf', 'perl', 'shell', 'buildPerl']:
        p = config[name]
        if not p.startswith('/nix/store/') or not os.path.isfile(p) or not os.access(p, os.X_OK):
            raise ValueError(('missing explicit final provider', name))
    planned = link_plan(root, files, links, old, new, helper.replace_paths)
    changes, rpaths, removals = {}, {}, set()
    for group in groups:
        roles = {role(name) for name in group}
        if len(roles) != 1:
            raise ValueError(('conflicting installed hardlink roles', group))
        name = group[0]; p = files[name]; data = p.read_bytes()
        selected_role = next(iter(roles))
        if selected_role == 'evidence':
            removals.update(group)
            continue
        if selected_role in ('text', 'rehash'):
            helper.text(data, group)
        if data.startswith(b'\x7fELF'):
            hits = inspect_elf(p, old, config['readelf'])
            probe = subprocess.run([config['patchelf'], '--print-rpath', str(p)], check=True, capture_output=True)
            if probe.stderr or not probe.stdout.endswith(b'\n'):
                raise ValueError(('RPATH inspector diagnostics', name))
            raw = probe.stdout[:-1]
            if any(c in raw for c in [b'\0', b'\n', b'\r']):
                raise ValueError(('malformed RPATH', name))
            for component in raw.split(b':'):
                if component and not (component.startswith(b'/nix/store/') or re.match(rb'^\$(?:ORIGIN|LIB|PLATFORM)(?:/|$)|^\$\{(?:ORIGIN|LIB|PLATFORM)\}(?:/|$)', component)):
                    raise ValueError(('non-loader-relative RPATH', name, component))
            for hit in hits:
                if hit['section'] == '.dynstr':
                    if hit.get('exclusiveRpath', '').encode() != raw:
                        raise ValueError(('nonexclusive dynamic self path', name))
                elif (hit['section'] != '.rodata' or not hit['readonlyAllocated']
                      or hit['stringEnd'] < 0
                      or data[hit['stringStart']:hit['offset']] not in (b'', b'OPENSSLDIR: \"', b'ENGINESDIR: \"', b'MODULESDIR: \"')
                      or not data[hit['offset']:].startswith(old+b'/')):
                    raise ValueError(('unsupported compiled self path', name, hit))
                else:
                    a, b = hit['stringStart'], hit['stringEnd']
                    data = data[:a] + helper.replace_paths(data[a:b], old, new) + data[b:]
            relocated = helper.replace_paths(raw, old, new)
            if relocated != raw:
                rpaths[name] = relocated.decode()
        elif data.startswith(b'!<arch>\n'):
            data = relocate_archive(data, old, new, config['readelf'], helper.replace_paths)
        elif old in data:
            data = helper.replace_paths(helper.text(data, group), old, new)
        if selected_role == 'rehash':
            if not config['rehash']:
                raise ValueError('unexpected installed c_rehash')
            helper.text(data, name)
            first, sep, body = data.partition(b'\n')
            if not sep or not re.fullmatch(rb'#!.*perl(?:[ \t]+-[wT])?', first):
                raise ValueError('invalid c_rehash Perl frontend')
            body = body.replace(config['buildPerl'].encode(), config['perl'].encode())
            # c_rehash uses OPENSSL or its configured prefix, and some old
            # versions fall back to PATH. Own that path explicitly after split.
            preamble = ('BEGIN { $ENV{PATH} = ' + json.dumps(str(root/'bin')+':'+':'.join(config['tools']))
                        + '; $ENV{OPENSSL} = ' + json.dumps(str(root/'bin/openssl')) + ' unless defined $ENV{OPENSSL}; }\n').encode()
            data = b'#!'+config['perl'].encode()+b'\n'+preamble+body
        elif data.startswith(b'#!') and p.stat().st_mode & 0o111:
            helper.text(data, name)
            first, sep, body = data.partition(b'\n')
            if re.fullmatch(rb'#!.*(?:sh|bash)(?:[ \t]+-e)?', first):
                data = b'#!'+config['shell'].encode()+sep+body
            else:
                raise ValueError(('unreviewed installed executable script', name, first))
        if data != p.read_bytes() or name in rpaths:
            changes[name] = data
    if config['rehash'] and 'bin/c_rehash' not in files:
        raise ValueError('missing c_rehash')
    for group in groups:
        name = group[0]; p = files[name]
        if name in removals:
            for alias in group:
                files[alias].unlink()
        elif name in changes:
            mode = stat.S_IMODE(p.stat().st_mode)
            p.chmod(mode | stat.S_IWUSR)
            with p.open('r+b') as f:
                f.write(changes[name]); f.truncate()
            if name in rpaths:
                result = subprocess.run([config['patchelf'], '--set-rpath', rpaths[name], str(p)], check=True, capture_output=True)
                if result.stderr or result.stdout:
                    raise ValueError('patchelf mutation diagnostics')
            for alias in group[1:]:
                files[alias].unlink(); os.link(p, files[alias])
            p.chmod(mode)
    for name, target in planned.items():
        if target != links[name]:
            p = root/name; p.unlink(); p.symlink_to(target)
    helper.audit(str(root), [artifact])
    return {'relocated': sorted(changes), 'removedOperationalEvidence': sorted(removals)}


if __name__ == '__main__':
    print(json.dumps(finalize(load(sys.argv[2]), sys.argv[3], sys.argv[4], json.loads(sys.argv[5]), load(sys.argv[1]).relocate, load(sys.argv[6]).inspect), sort_keys=True))
