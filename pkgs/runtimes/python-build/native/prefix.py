"""CPython's explicit prefix/shell adaptations; validate ownership before writes."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

root = Path(sys.argv[1])
config = json.loads(sys.argv[2])
action = sys.argv[3]
if not root.is_absolute() or root.is_symlink() or not root.is_dir():
    raise ValueError("expected owned directory")
if any(part in ("", ".", "..") for part in str(root).split("/")[1:]):
    raise ValueError("unsafe root components")
for parent in root.parents:
    if parent.is_symlink():
        raise ValueError("symlink root component")
# Validate all components and link counts before the first mutation. Symlinks
# are never traversed; internal output aliases are retained as installed.
files = []
def walk(directory):
    for path in sorted(directory.iterdir()):
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            if action in ('validate-source', 'prepare'):
                raise ValueError(f"source symlink: {path}")
            continue
        if stat.S_ISDIR(info.st_mode):
            walk(path)
        elif stat.S_ISREG(info.st_mode):
            files.append((path, info))
        else:
            raise ValueError(f"special file: {path}")
walk(root)
counts = {}
for p, i in files:
    key = (i.st_dev, i.st_ino)
    counts[key] = counts.get(key, 0) + 1
for p, i in files:
    if counts[(i.st_dev, i.st_ino)] != i.st_nlink:
        raise ValueError(f"external hardlink: {p}")
owned = {p.relative_to(root).as_posix(): (p, i) for p, i in files}
def replace(name, old, new, required=True):
    if name not in owned:
        raise ValueError(f"not an owned regular file: {name}")
    p, i = owned[name]
    data = p.read_text()
    if required and old not in data:
        raise ValueError(f"missing CPython marker: {name}: {old!r}")
    write(p, i, data.replace(old, new).encode())
def write(p, i, data):
    try:
        p.chmod(stat.S_IMODE(i.st_mode) | stat.S_IWUSR)
        p.write_bytes(data)
    finally:
        p.chmod(stat.S_IMODE(i.st_mode))
        os.utime(p, ns=(i.st_atime_ns, i.st_mtime_ns))
if action == 'validate-source':
    pass
elif action == 'prepare':
    shell = config['shell']
    replace('Lib/subprocess.py', '@TVP_SHELL@', shell)
    replace('Makefile.pre.in', 'SHELL=\t\t/bin/sh -e', 'SHELL= ' + shell + ' -e')
    replace('Misc/python-config.sh.in', '#!/bin/sh', '#!' + shell)
    for old, new in [('dirname ', config['coreutils']+'/bin/dirname '),
                     ('which readlink', 'command -v '+config['coreutils']+'/bin/readlink'),
                     ('readlink -f', config['coreutils']+'/bin/readlink -f'),
                     ('| sed ', '| '+config['sed']+'/bin/sed ')]:
        replace('Misc/python-config.sh.in', old, new)
elif action == 'install':
    for name, (p, i) in owned.items():
        data = None
        if name.endswith('.py') or p.name in ('idle3.12', 'pydoc3.12'):
            original = p.read_bytes()
            if original.startswith(b'#!'):
                data = b'#!'+str(root).encode()+b'/bin/python3\n'+original.split(b'\n', 1)[1]
        if '/config-' in name and p.name in ('install-sh','makesetup'):
            original = p.read_bytes()
            assert original.startswith(b'#!')
            data = ('#!'+config['shell']+'\nexport PATH='+config['helperPath']+'\n').encode()+original.split(b'\n', 1)[1]
        if data is not None:
            write(p, i, data)
    # A macOS source-maintenance downloader has no role in this Linux profile.
    name = 'lib/python3.12/ctypes/macholib/fetch_macholib'
    p, _ = owned[name]
    p.unlink()
elif action == 'transform':
    try:
        for p, i in files:
            p.chmod(stat.S_IMODE(i.st_mode) | stat.S_IWUSR)
        subprocess.run([config['shell'], '-euc', sys.argv[4]], check=True)
    finally:
        for p, i in files:
            p.chmod(stat.S_IMODE(i.st_mode))
else:
    raise ValueError(action)
