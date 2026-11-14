"""Confined textual preparation for ordinary GDBM and LibYAML sources.

Selections name script/fixture inputs, never documentation or binary locale data.
All targets, aliases, edits and patch targets are validated before source writes.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import sys

shell, config_json = sys.argv[1:]
config = json.loads(config_json)
root = Path.cwd().resolve(strict=True)
files = {}
aliases = []
for directory, dirs, names in os.walk(root, followlinks=False):
    for name in sorted(dirs + names):
        path = Path(directory) / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            target = path.resolve(strict=True)
            if os.path.isabs(os.readlink(path)) or not target.is_relative_to(root) or not stat.S_ISREG(target.stat().st_mode):
                raise ValueError(('unsafe source alias', path))
            aliases.append(path)
        elif stat.S_ISREG(info.st_mode):
            if info.st_nlink != 1:
                raise ValueError(('source hardlink', path))
            files[path] = path.read_bytes()
        elif not stat.S_ISDIR(info.st_mode):
            raise ValueError(('special source node', path))

def selector(raw):
    if not raw or any(p in ('', '.', '..') for p in raw.split('/')):
        raise ValueError(('invalid selector', raw))
    path = root
    for part in raw.split('/'):
        path = path / part
        if path.is_symlink():
            raise ValueError(('selected source alias', path))
        path.lstat()
    return path

selections = [selector(s) for s in config['selections']]
def selected(path):
    return any(path == s or path.is_relative_to(s) for s in selections)
for path in aliases:
    if selected(path):
        raise ValueError(('selected source alias', path))
changes = {}
for path, data in files.items():
    if not selected(path):
        continue
    if b'\0' in data:
        raise ValueError(('NUL in selected source', path))
    if data.startswith(b'#!'):
        front, body = data.split(b'\n', 1)
        match = re.fullmatch(rb'#![ \t]*(?:/(?:bin|usr/bin)/(?:sh|bash)|/usr/bin/env (?:sh|bash))(?: (-e|-))?', front)
        if not match:
            raise ValueError(('unsupported selected interpreter', path, front))
        changes[path] = b'#!' + shell.encode() + (b' ' + match[1] if match[1] else b'') + b'\n' + body
    elif str(path.relative_to(root)) in config.get('shellFragments', {}):
        headers = config['shellFragments'][str(path.relative_to(root))]
        headers = [headers] if isinstance(headers, str) else headers
        if not any(data.startswith(header.encode() + b'\n') for header in headers):
            raise ValueError(('shell fragment provenance', path))
    elif path.stat().st_mode & 0o111:
        raise ValueError(('unsupported executable source', path))
configure = selector('configure')
if configure not in changes:
    raise ValueError('configure must be a selected shell script')
changes[configure] = changes[configure].replace(b'/usr/bin/file', b'file')
anchors = {}
for raw, expected in config['libtoolAnchors'].items():
    path = selector(raw)
    data = changes.get(path, files[path])
    search = b' '.join(f[2:].encode() for f in shlex.split(os.environ.get('NIX_LDFLAGS', '')) if f.startswith('-L'))
    data, count = re.subn(rb'eval (sys_lib_search_path=).*', lambda m: m[1] + b"'" + search + b"'", data)
    if count != expected:
        raise ValueError(('libtool anchor', path, count, expected))
    anchors[raw] = count
    changes[path] = re.sub(rb'eval sys_lib_.+search_path=.*', b'', data)
for edit in config.get('edits', []):
    path = selector(edit['path'])
    data = changes.get(path, files[path])
    before, after = edit['before'].encode(), edit['after'].encode()
    count = data.count(before)
    if count != edit['count'] or b'\0' in data:
        raise ValueError(('text edit anchor', path, count))
    changes[path] = data.replace(before, after)
    anchors[edit['path'] + ':' + edit['before']] = count
# Apply unified replacement hunks in memory; never execute patch filenames or
# allow file creation/deletion. The definitions retain the original patch bytes.
for patch in config.get('patches', []):
    lines = Path(patch).read_bytes().splitlines(keepends=True)
    index = 0
    while index < len(lines):
        if not lines[index].startswith(b'--- a/'):
            raise ValueError('expected unified a/ target')
        raw = lines[index][6:].strip().decode()
        path = selector(raw)
        index += 1
        if index >= len(lines) or lines[index] != b'+++ b/' + raw.encode() + b'\n':
            raise ValueError('patch must replace one regular target')
        if path not in files or b'\0' in files[path]:
            raise ValueError(('patch needs regular text target', path))
        original = changes.get(path, files[path]).splitlines(keepends=True)
        result = []
        position = 0
        index += 1
        while index < len(lines) and lines[index].startswith(b'@@ '):
            match = re.fullmatch(rb'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@[^\n]*\n', lines[index])
            if not match:
                raise ValueError('invalid patch hunk')
            first = int(match[1]) - 1
            old_count = int(match[2] or b'1')
            new_count = int(match[4] or b'1')
            if first < position:
                raise ValueError('overlapping patch hunks')
            result.extend(original[position:first])
            position = first
            before = after = 0
            index += 1
            while index < len(lines) and lines[index][:1] in (b' ', b'-', b'+') and not lines[index].startswith(b'--- '):
                kind, value = lines[index][:1], lines[index][1:]
                if kind in (b' ', b'-'):
                    if position >= len(original) or original[position] != value:
                        raise ValueError(('patch anchor mismatch', path, position))
                    position += 1
                    before += 1
                if kind in (b' ', b'+'):
                    result.append(value)
                    after += 1
                index += 1
            if (before, after) != (old_count, new_count):
                raise ValueError('patch hunk count mismatch')
        result.extend(original[position:])
        changes[path] = b''.join(result)
for path in changes:
    if os.path.lexists(str(path) + '.tvp-prepare'):
        raise ValueError(('preparation collision', path))
for path, data in changes.items():
    info = path.stat()
    temp = Path(str(path) + '.tvp-prepare')
    with temp.open('xb') as stream:
        stream.write(data)
    temp.chmod(stat.S_IMODE(info.st_mode))
    os.utime(temp, ns=(info.st_atime_ns, info.st_mtime_ns))
for path in changes:
    os.replace(str(path) + '.tvp-prepare', path)
print(json.dumps({'validatedFiles': len(files), 'anchors': anchors, 'adaptations': {
    str(p.relative_to(root)): hashlib.sha256(d).hexdigest() for p, d in changes.items()
}}, sort_keys=True))
