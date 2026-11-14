"""GN-local flat Gitiles tree extraction; validate the whole archive first.

Gitiles GN has only directories and regular files. Reject links and special
entries rather than interpreting them; no source symlinks are synthesized.
"""
import os
from pathlib import Path, PurePosixPath
import sys
import tarfile


def unpack(archive, output):
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError('output must be fresh')
    with tarfile.open(archive, 'r:gz') as tar:
        members = tar.getmembers()
        names = {}
        for member in members:
            name = member.name.removeprefix('./').rstrip('/')
            parts = name.split('/')
            if not name or name.startswith('/') or any(p in ('', '.', '..') for p in parts):
                raise ValueError('unsafe path')
            if not (member.isdir() or member.isfile()) or name in names:
                raise ValueError('unsupported type or duplicate path')
            names[name] = member
        for name in names:
            for parent in PurePosixPath(name).parents:
                if str(parent) != '.' and str(parent) in names and not names[str(parent)].isdir():
                    raise ValueError('non-directory parent')
        output.mkdir()
        for name, member in names.items():
            dest = output / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            if member.isdir():
                dest.mkdir(exist_ok=True)
            else:
                with tar.extractfile(member) as source, dest.open('xb') as target:
                    while chunk := source.read(1024 * 1024):
                        target.write(chunk)
                dest.chmod(0o755 if member.mode & 0o111 else 0o644)
        # fetchzip normalizes writable permissions too; the NAR records only +x.
        for directory, _, _ in os.walk(output):
            Path(directory).chmod(0o755)


if __name__ == '__main__':
    unpack(*sys.argv[1:])
