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
    changes, rpaths, removals, planned = {}, {}, set(), {}
    for group in groups:
        roles = set()
        for name in group:
            if name in ('nix-support/upstream.raw', 'nix-support/upstream.exit'):
                roles.add('evidence')
            elif name == 'bin/c_rehash':
                roles.add('rehash')
            elif name.startswith(('include/', 'lib/pkgconfig/', 'lib/cmake/', 'etc/')):
                roles.add('text')
            else:
                roles.add('ordinary')
        if len(roles) != 1:
            raise ValueError(('conflicting installed hardlink roles', group))
        name = group[0]; p = files[name]; data = p.read_bytes()
        role = next(iter(roles))
        if role == 'evidence':
            removals.update(group)
            continue
        if role in ('text', 'rehash'):
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
        if role == 'rehash':
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
    for name, target in links.items():
        planned[name] = helper.replace_paths(target.encode(), old, new).decode()
    def resolve(name, active):
        if name in active:
            raise ValueError(('symlink cycle', name))
        target = planned[name]
        if target.startswith('/'):
            if not target.startswith(str(root)+'/'):
                raise ValueError(('outside installed link', name))
            parts = list(Path(target).relative_to(root).parts)
        else:
            parts = list(Path(name).parent.parts)+list(Path(target).parts)
        result = []
        for part in parts:
            if part == '..':
                if not result:
                    raise ValueError(('escaping link', name))
                result.pop()
            elif part != '.':
                result.append(part)
                nested = '/'.join(result)
                if nested in planned:
                    result = resolve(nested, active | {name})
        final = '/'.join(result)
        if final in removals or not (root/final).exists():
            raise ValueError(('dangling planned link', name))
        return result
    for name in planned:
        resolve(name, set())
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
