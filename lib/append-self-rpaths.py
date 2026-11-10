"""Append explicit output-relative dlopen directories after provider repair.

This operation selects only recipe-declared native host roles. It never strips,
changes loaders, follows symlinks, or edits shared inodes.
"""
import sys
sys.path.insert(0, sys.argv[3])
from common import elf, files, invocation, preserving_times, selected, tool

root, config = invocation()
directories = []
for relative in config['directories']:
    directory = selected(root, relative)
    if ':' in str(directory):
        raise ValueError('self library directory contains the ELF path separator')
    if not directory.is_dir():
        raise ValueError('missing self library directory')
    directories.append(str(directory))
operations = []
for path in files(root, config['paths']):
    if path.stat().st_nlink != 1:
        raise ValueError(f'shared host file: {path}')
    kind = elf(path, config['readelf'])
    if kind is None or not kind[0]:
        continue
    before = tool(config['patchelf'], '--print-rpath', path).rstrip('\n')
    paths = list(filter(None, before.split(':')))
    for directory in directories:
        if directory not in paths:
            paths.append(directory)
    operations.append((path, ':'.join(paths)))
for path, value in operations:
    preserving_times(path, lambda: tool(config['patchelf'], '--set-rpath', value, path))
    if tool(config['patchelf'], '--print-rpath', path).rstrip('\n') != value:
        raise ValueError('self RPATH verification failed')
