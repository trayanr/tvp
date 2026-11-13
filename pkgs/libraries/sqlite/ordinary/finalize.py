"""Validate the copied namespace, then relocate installed text and drop raw logs.

ELF inspection/rebasing/strip remain explicit shared output operations in recipes.
This helper never modifies executable bytes or follows a discovered link.
"""
import gzip
import os
from pathlib import Path
import stat
import sys


def finalize(root, artifact):
    root = Path(root)
    artifact = Path(artifact)
    for p in [root, artifact]:
        if not p.is_absolute() or p.is_symlink() or not p.is_dir() or p.resolve(strict=True) != p:
            raise ValueError('expected canonical roots')
    if root == artifact or root.is_relative_to(artifact) or artifact.is_relative_to(root):
        raise ValueError('overlapping roots')
    aliases = {}
    links = []
    evidence = root / 'nix-support/sqlite-upstream'
    if evidence.exists() and not evidence.is_dir():
        raise ValueError('raw evidence root is not a directory')
    for parent, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            path = Path(parent) / name
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode):
                if path == evidence or path.is_relative_to(evidence):
                    raise ValueError(f'raw evidence alias: {path}')
                value = os.readlink(path)
                target = path.resolve(strict=True)
                if not target.is_relative_to(root):
                    raise ValueError(f'outside link: {path}')
                if str(artifact) in value:
                    raise ValueError(f'unplanned artifact symlink: {path}')
                if target == evidence or target.is_relative_to(evidence):
                    raise ValueError(f'surviving alias to removed evidence: {path}')
                links.append(path)
            elif stat.S_ISREG(info.st_mode):
                aliases.setdefault((info.st_dev, info.st_ino), []).append(path)
            elif stat.S_ISDIR(info.st_mode):
                if path != evidence and path.is_relative_to(evidence):
                    raise ValueError(f'nested raw evidence directory: {path}')
            else:
                raise ValueError(f'special file: {path}')
    def role(path):
        rel = path.relative_to(root).as_posix()
        if rel.startswith('nix-support/sqlite-upstream/'):
            return 'raw'
        if rel.startswith('share/man/') and path.suffix == '.gz':
            return 'compressed-metadata'
        if path.suffix in ('.pc', '.la', '.tcl') or rel.startswith('share/man/'):
            return 'metadata'
        return 'artifact'
    changes = []
    removals = []
    for paths in aliases.values():
        if paths[0].stat().st_nlink != len(paths) or len({role(p) for p in paths}) != 1:
            raise ValueError(f'unsafe hardlink roles: {paths}')
        p = paths[0]
        if role(p) == 'raw':
            removals.extend(paths)
        elif role(p) in ('metadata', 'compressed-metadata'):
            data = p.read_bytes()
            compressed = role(p) == 'compressed-metadata'
            text = gzip.decompress(data) if compressed else data
            if b'\0' in text:
                raise ValueError(f'not text: {p}')
            text.decode('utf-8')
            relocated = text.replace(os.fsencode(artifact), os.fsencode(root))
            if relocated != text:
                changes.append((p, gzip.compress(relocated, mtime=0) if compressed else relocated))
    # All validation is complete before the first write/unlink. Preserve aliases.
    for path, data in changes:
        info = path.stat()
        with path.open('r+b') as f:
            f.write(data)
            f.truncate()
        os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
    for path in removals:
        path.unlink()
    if evidence.exists():
        evidence.rmdir()


if __name__ == '__main__':
    finalize(sys.argv[1], os.environ['TVP_ARTIFACT_ROOT'])
