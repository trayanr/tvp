"""Save and restore explicit compiled directories using the existing checkpoint model.

MIG004 bounded extension: CMake keeps source/build siblings; Zstd retains its
source-bound sibling directory. This module supplies no runner or acceptance.
"""
import json
import os
from pathlib import Path
import shutil
import stat
import sys


def canonical(value):
    path = Path(value)
    if not path.is_absolute() or any(x in ('', '.', '..') for x in str(value).split('/')[1:]):
        raise ValueError('canonical absolute path required')
    return path


def private(path):
    value = str(path)
    if not (value == '/build' or value.startswith('/build/') or value.startswith('/tmp/nix-build-') or value.startswith('/nix/var/nix/builds/')):
        raise ValueError('destination is outside a private Nix build directory')
    probe = path
    while not probe.exists() and not probe.is_symlink():
        probe = probe.parent
    if probe.resolve() != probe or probe.is_symlink() or not probe.is_dir():
        raise ValueError('destination parent is not a private real directory')


def validate(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('real directory required')
    for parent, dirs, files in os.walk(root, followlinks=False):
        for path in [Path(parent)] + [Path(parent) / n for n in dirs + files]:
            mode = path.lstat().st_mode
            if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode) or stat.S_ISLNK(mode)):
                raise ValueError('unsupported checkpoint object')


def save(workspace, destination, directories, tree):
    workspace = canonical(workspace)
    destination = canonical(destination)
    selected = [canonical(x) for x in directories]
    tree = canonical(tree)
    if not selected or tree not in selected or len(set(selected)) != len(selected):
        raise ValueError('explicit unique directories and selected tree required')
    if any(a != b and (a.is_relative_to(b) or b.is_relative_to(a)) for a in selected for b in selected):
        raise ValueError('checkpoint directory overlap')
    if destination.exists() or destination.is_symlink():
        raise ValueError('checkpoint destination exists')
    for source in selected:
        private(source)
        validate(source)
        if destination.is_relative_to(source):
            raise ValueError('checkpoint would include itself')
    records = []
    for i, source in enumerate(selected):
        times = {}
        for parent, dirs, files in os.walk(source, followlinks=False):
            for path in [Path(parent)] + [Path(parent) / n for n in dirs + files]:
                times[str(path.relative_to(source))] = path.lstat().st_mtime_ns
        records.append({'directory': str(source), 'member': str(i), 'timestamps': times})
    epoch = (workspace / 'source-date-epoch').read_text().strip()
    destination.mkdir(parents=True)
    for source, record in zip(selected, records):
        shutil.copytree(source, destination / record['member'], symlinks=True)
    (destination / 'layout.json').write_text(json.dumps({'schema': 1, 'kind': 'explicit-multiple-directories', 'workspace': str(workspace), 'tree': str(tree), 'sourceDateEpoch': epoch, 'directories': records}) + '\n')


def restore(checkpoint, workspace):
    checkpoint = canonical(checkpoint)
    workspace = canonical(workspace)
    layout = json.loads((checkpoint / 'layout.json').read_text())
    if layout.get('schema') != 1 or layout.get('kind') != 'explicit-multiple-directories':
        raise ValueError('unsupported checkpoint layout')
    original_workspace = canonical(layout['workspace'])
    private(original_workspace)
    records = layout['directories']
    selected = [canonical(x['directory']) for x in records]
    if not selected or len(set(selected)) != len(selected) or canonical(layout['tree']) not in selected:
        raise ValueError('invalid directory selection')
    if any(a != b and (a.is_relative_to(b) or b.is_relative_to(a)) for a in selected for b in selected):
        raise ValueError('overlapping destinations')
    if any(not p.is_relative_to(original_workspace.parent) for p in selected):
        raise ValueError('destination outside recorded workspace generation')
    # Validate every source and destination before making the first directory.
    for i, (target, record) in enumerate(zip(selected, records)):
        if record['member'] != str(i):
            raise ValueError('unexpected checkpoint member')
        private(target)
        if target.exists() or target.is_symlink():
            raise ValueError('restore destination exists')
        source = checkpoint / record['member']
        validate(source)
        names = set()
        for parent, dirs, files in os.walk(source, followlinks=False):
            for path in [Path(parent)] + [Path(parent) / n for n in dirs + files]:
                names.add(str(path.relative_to(source)))
        if names != set(record['timestamps']):
            raise ValueError('checkpoint timestamp coverage gap')
    for target, record in zip(selected, records):
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(checkpoint / record['member'], target, symlinks=True)
        for parent, dirs, files in os.walk(target, followlinks=False):
            for path in [Path(parent)] + [Path(parent) / n for n in dirs + files]:
                if not path.is_symlink():
                    path.chmod(path.stat().st_mode | stat.S_IWUSR)
                stamp = record['timestamps'][str(path.relative_to(target))]
                os.utime(path, ns=(stamp, stamp), follow_symlinks=False)
    (workspace / 'tree-path').write_text(layout['tree'] + '\n')
    (workspace / 'workspace-path').write_text(layout['workspace'] + '\n')
    (workspace / 'source-date-epoch').write_text(layout['sourceDateEpoch'] + '\n')


if __name__ == '__main__':
    if sys.argv[1] == 'save':
        save(sys.argv[2], sys.argv[3], json.loads(sys.argv[4]), sys.argv[5])
    elif sys.argv[1] == 'restore':
        restore(sys.argv[2], sys.argv[3])
    else:
        raise ValueError('expected save or restore')
