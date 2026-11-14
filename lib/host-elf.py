"""Shallow, explicitly selected host ELF repair. Validate the whole batch first.

Never traverse discovered symlinks, target sysroots or compiler resources. Reject
external/shared hardlinks before any writes; no build-closure runtime permission.
"""
import glob
import os
from pathlib import Path
import stat
import sys

sys.path.insert(0, sys.argv[3])
from common import invocation, selected, elf, tool, store_directories

root, config = invocation()
loader = config['loader']
if not isinstance(loader, str) or not loader.startswith('/nix/store/'):
    raise ValueError('expected declared store loader')
if not Path(loader).is_file() or not os.access(loader, os.X_OK):
    raise ValueError('loader must be executable')
libraries = store_directories(config['libraries'])
paths = config['paths']
patterns = config['patterns']
if not isinstance(paths, list) or not paths or not isinstance(patterns, list):
    raise ValueError('explicit host directories required')
for pattern in patterns:
    if not isinstance(pattern, str) or any(p in ('', '.', '..') for p in pattern.split('/')) or pattern.startswith('/'):
        raise ValueError('unsafe host pattern')
    matches = sorted(glob.glob(str(root / pattern)))
    if not matches:
        raise ValueError(f'required host pattern matched no directories: {pattern}')
    paths += [str(Path(p).relative_to(root)) for p in matches]
# Resolve all selectors before inspecting or modifying any file.
directories = [selected(root, p) for p in paths]
files = []
seen = set()
for directory in directories:
    if not directory.is_dir():
        raise ValueError(f'expected host directory: {directory}')
    for path in sorted(directory.iterdir()):
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode) or stat.S_ISDIR(info.st_mode):
            continue
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError(f'unsupported/shared host file: {path}')
        if path not in seen:
            seen.add(path)
            files.append(path)
operations = []
for path in files:
    kind = elf(path, config['readelf'])
    if kind is None or not kind[0]:
        continue
    old = tool(config['patchelf'], '--print-rpath', path).strip()
    origins = []
    for entry in filter(None, old.split(':')):
        normalized = entry.replace('${ORIGIN}', '$ORIGIN')
        if normalized != '$ORIGIN' and not normalized.startswith('$ORIGIN/'):
            raise ValueError(f'unsupported upstream host rpath: {entry}')
        target = (path.parent / normalized[len('$ORIGIN'):].lstrip('/')).resolve()
        if not target.is_relative_to(root):
            raise ValueError(f'origin escapes output: {entry}')
        origins.append(entry)
    rpath = ':'.join(dict.fromkeys(origins + libraries))
    operations.append((path, kind[1], rpath))
for path, interpreter, rpath in operations:
    info = path.stat()
    if interpreter:
        tool(config['patchelf'], '--set-interpreter', loader, path)
    tool(config['patchelf'], '--set-rpath', rpath, path)
    # Keep upstream self/dlopen paths. Shrinking can drop unreferenced dlopen libs.
    if tool(config['patchelf'], '--print-rpath', path).strip() != rpath:
        raise ValueError('host rpath verification failed')
    if interpreter and tool(config['patchelf'], '--print-interpreter', path).strip() != loader:
        raise ValueError('host loader verification failed')
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
