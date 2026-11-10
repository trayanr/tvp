"""Validate the complete tar namespace before the selected tar extracts anything.

Keep every top-level entry. Reject special files, duplicate non-directory entries,
hardlinks and traversal through symlink parents. Safe relative symlinks survive.
"""
import posixpath
import sys
import tarfile


def validate(archive):
    entries = {}
    with tarfile.open(archive, 'r:gz') as stream:
        for member in stream:
            name = member.name
            if name.startswith('/') or '\0' in name or '..' in name.split('/'):
                raise ValueError(f'unsafe archive member: {name!r}')
            name = posixpath.normpath(name)
            if name == '.':
                if not member.isdir():
                    raise ValueError('archive root must be a directory')
                continue
            if name in entries and not (member.isdir() and entries[name].isdir()):
                raise ValueError(f'duplicate archive member: {name}')
            if not (member.isfile() or member.isdir() or member.issym()):
                raise ValueError(f'unsupported archive member: {name}')
            if member.issym():
                target = member.linkname
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
                if '..' in target.split('/') or target.startswith('/') or resolved == '..' or resolved.startswith('../') or '\0' in target:
                    raise ValueError(f'escaping archive link: {name}')
            entries[name] = member
    if not entries:
        raise ValueError('empty archive')
    for name in entries:
        parent = posixpath.dirname(name)
        while parent:
            if parent in entries and not entries[parent].isdir():
                raise ValueError(f'non-directory archive parent: {parent}')
            parent = posixpath.dirname(parent)


if __name__ == '__main__':
    validate(sys.argv[1])
