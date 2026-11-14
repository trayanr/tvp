"""Copy locked DEPS; preflight destinations and source edit scopes before writes."""
import json
import os
from pathlib import Path
import shutil
import stat
import sys
sys.path.insert(0, sys.argv[3])
from common import selected

root = Path.cwd().resolve(strict=True)
entries = json.loads(sys.argv[1])
patches = json.loads(sys.argv[2])


def destination(selector):
    if (not isinstance(selector, str) or selector.startswith('/')
            or any(p in ('', '.', '..') for p in selector.split('/'))):
        raise ValueError('unsafe DEPS destination')
    current = root
    for part in selector.split('/'):
        current /= part
        if current.is_symlink():
            raise ValueError(f'symlink DEPS destination: {current}')
        if current.exists() and not current.is_dir():
            if current != root / selector or not current.is_file() or current.stat().st_nlink != 1:
                raise ValueError(f'unsupported/shared DEPS destination: {current}')
    return current


def edit_scopes():
    for directory in ['build/config', 'tools', 'build', 'runtime/tools']:
        if not selected(root, directory).is_dir():
            raise ValueError('expected source directory')
    destination('build/config/gclient_args.gni')
    for patch in patches:
        for line in Path(patch).read_text().splitlines():
            if line.startswith(('--- a/', '+++ b/')):
                path = selected(root, line[6:])
                if not path.is_file() or path.stat().st_nlink != 1:
                    raise ValueError('patch target must be an unshared regular file')
    # Never follow tools/sdks/dart-sdk into an immutable bootstrap output.
    for selector in ['tools', 'build', 'runtime/tools']:
        for current, dirs, names in os.walk(selected(root, selector), followlinks=False):
            for name in names:
                path = Path(current) / name
                if not path.is_symlink() and path.stat().st_nlink != 1:
                    raise ValueError(f'shared source edit scope: {path}')


for entry in entries:
    target = destination(entry['path'])
    if target.exists() and not target.is_dir():
        raise ValueError('expected DEPS directory')
    source = Path(entry['src'])
    if not source.is_absolute() or source.is_symlink() or not source.is_dir():
        raise ValueError('expected immutable source directory')
    for other in entries:
        if other is not entry and (other['path'] == entry['path'] or other['path'].startswith(entry['path'] + '/')):
            raise ValueError('overlapping DEPS destinations unsupported')
    # copytree must not overwrite a symlink or shared inode already in the SDK.
    for path in source.rglob('*'):
        destination(entry['path'] + '/' + str(path.relative_to(source)))
edit_scopes()
for entry in entries:
    target = destination(entry['path'])
    target.mkdir(parents=True, exist_ok=True)
    shutil.copytree(entry['src'], target, symlinks=True, dirs_exist_ok=True)
    for path in [target, *target.rglob('*')]:
        if not path.is_symlink():
            path.chmod(stat.S_IMODE(path.stat().st_mode) | stat.S_IWUSR)
edit_scopes()
