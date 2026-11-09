"""Exercise source boundaries without compiling Gettext or touching real inputs."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


helper = Path(sys.argv[1]).resolve()
fixed = {
    'gettext-runtime/src/gettext.sh.in': b'#!/bin/sh\n  gettext text\n  ngettext text texts 2\nenvsubst hello\n',
    'gettext-tools/config.h.in': b'#define BOURNE_SHELL "/bin/sh"\n',
    'libtextstyle/configure': b"#!/bin/sh\nnames_next_round='ncurses '\n",
    'gettext-tools/src/project-id': b'#!/bin/sh\nlast=`/bin/pwd`\ncurr=`/bin/pwd`\n',
}
stamp = 1000000000000000000


def put(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    os.utime(path, ns=(stamp, stamp))


def snapshot(root):
    result = {}
    for directory, _, names in os.walk(root, followlinks=False):
        for name in names:
            path = Path(directory) / name
            info = path.lstat()
            if stat.S_ISREG(info.st_mode):
                result[str(path.relative_to(root))] = (path.read_bytes(), info.st_mtime_ns)
    return result


def case(kind, relative):
    with tempfile.TemporaryDirectory(prefix='gettext-source-boundary-') as directory:
        root = Path(directory)
        source = root / 'source'
        for name, data in fixed.items():
            put(source / name, data)
        put(source / 'tools/perl', b'#!/usr/bin/perl\nexit 0;\n')
        put(source / 'tools/python', b'#!/usr/bin/env python3\npass\n')
        put(source / 'build-aux/ltmain.sh', b'#!/bin/sh\neval sys_lib_search_path=example\neval sys_lib_dlsearch_path=example\n')
        path = source / relative
        outside = root / 'outside'
        outside.mkdir()
        if kind == 'parent-symlink':
            # Move the complete parent so the fixture stays valid for all targets.
            destination = outside / 'parent'
            path.parent.rename(destination)
            path.parent.symlink_to(destination, target_is_directory=True)
        elif kind in ('leaf-symlink', 'hardlink'):
            destination = outside / 'target'
            put(destination, path.read_bytes())
            path.unlink()
            if kind == 'leaf-symlink':
                path.symlink_to(destination)
            else:
                os.link(destination, path)
        elif kind in ('missing', 'directory', 'fifo'):
            path.unlink()
            if kind == 'directory':
                path.mkdir()
            elif kind == 'fifo':
                os.mkfifo(path)
        before = snapshot(root)
        config = {'bash': '/selected/bash', 'perl': '/selected/perl', 'python': '/selected/python'}
        process = subprocess.run(
            [sys.executable, '-B', str(helper), json.dumps(config)],
            cwd=source,
            env=os.environ | {'out': str(root / 'output'), 'NIX_LDFLAGS': '-L/selected/lib'},
            capture_output=True, timeout=5,
        )
        if kind == 'regular':
            assert process.returncode == 0, process.stderr.decode()
            for name in fixed:
                assert (source / name).stat().st_mtime_ns == stamp, name
            project = (source / 'gettext-tools/src/project-id').read_bytes()
            assert b'/bin/pwd' not in project and project.count(b'pwd -P') == 2
            assert (source / 'tools/python').read_bytes().startswith(b'#!/selected/python/bin/python3\n')
        else:
            assert process.returncode != 0, (kind, relative)
            assert snapshot(root) == before, (kind, relative, 'unexpected mutation')


case('regular', next(iter(fixed)))
kinds = ['parent-symlink', 'leaf-symlink', 'hardlink', 'missing', 'directory', 'fifo']
for relative in fixed:
    for kind in kinds:
        case(kind, relative)
print(json.dumps({'sourceBoundaryCases': 1 + len(kinds) * len(fixed), 'passed': True}), file=sys.stderr)
