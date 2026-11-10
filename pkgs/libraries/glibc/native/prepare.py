"""Prepare the full source using only checked, private regular files."""
import os
from pathlib import Path
import stat
import sys


def private_files(root, *, preserve_linked_elf=False):
    root = Path(root)
    if not root.is_absolute():
        raise ValueError('expected absolute private root')
    # Check every parent before resolve; normalization must not hide an escape.
    if any(part in ('.', '..') for part in root.parts):
        raise ValueError('unsafe root')
    for path in [*reversed(root.parents), root]:
        if path.is_symlink():
            raise ValueError('symlink parent: ' + str(path))
    if not root.is_dir():
        raise ValueError('expected directory')
    result = []

    def walk(directory):
        for path in sorted(directory.iterdir()):
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode):
                continue  # Never follow, read or mutate a discovered link.
            if stat.S_ISDIR(info.st_mode):
                walk(path)
            elif stat.S_ISREG(info.st_mode):
                if info.st_nlink != 1:
                    if preserve_linked_elf:
                        with path.open('rb') as stream:
                            if stream.read(4) == b'\x7fELF':
                                continue  # Unchanged ELF aliases are never mutation candidates.
                    raise ValueError('non-private regular file: ' + str(path))
                result.append(path)
            else:
                raise ValueError('non-private regular file: ' + str(path))
    walk(root)
    return result


def replace(path, data):
    info = path.stat()
    path.write_bytes(data)
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))


def main():
    root, output, shell = sys.argv[1:]
    files = private_files(root)  # Validate entire tree before any mutation.
    rtld = Path(root) / 'elf/rtld.c'
    if rtld not in files:
        raise ValueError('missing regular rtld source')
    data = rtld.read_bytes()
    old = b'"/etc/ld.so.preload"'
    if data.count(old) != 1:
        raise ValueError('expected one upstream preload constant')
    pending = [(rtld, data.replace(old, ('"' + output + '/etc/ld.so.preload"').encode()))]
    for path in files:
        with path.open('rb') as stream:
            line = stream.readline(256)
        for prefix in (b'#!/bin/sh', b'#! /bin/sh', b'#!/bin/bash', b'#! /bin/bash'):
            if line.rstrip(b'\n') == prefix:
                _, newline, body = path.read_bytes().partition(b'\n')
                if not newline:
                    raise ValueError('unterminated script directive: ' + str(path))
                pending.append((path, b'#!' + shell.encode() + b'\n' + body))
                break
    for path, data in pending:
        replace(path, data)


if __name__ == '__main__':
    main()
