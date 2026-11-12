"""Guard an unpacked source namespace before patch/configure writes."""
import os
from pathlib import Path
import stat
import sys


def namespace(root):
    root = Path(root)
    if not root.is_absolute() or root.is_symlink() or root.resolve(strict=True) != root:
        raise ValueError('expected canonical non-symlink root')
    aliases = {}
    for parent, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            path = Path(parent) / name
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode):
                target = path.resolve(strict=True)
                if not target.is_relative_to(root):
                    raise ValueError(f'outside link: {path}')
            elif stat.S_ISREG(info.st_mode):
                aliases.setdefault((info.st_dev, info.st_ino), []).append(path)
            elif not stat.S_ISDIR(info.st_mode):
                raise ValueError(f'special file: {path}')
    for paths in aliases.values():
        if len(paths) != 1 or paths[0].stat().st_nlink != 1:
            raise ValueError(f'external hardlink: {paths}')
    return aliases


def text(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'expected regular text: {path}')
    data = path.read_bytes()
    if b'\0' in data:
        raise ValueError(f'NUL in text: {path}')
    data.decode('utf-8')
    return data


if __name__ == '__main__':
    root = Path(sys.argv[1])
    namespace(root)
    for name in ['configure', 'Makefile.in', 'VERSION']:
        text(root / name)
    for script in root.rglob('ltmain.sh'):
        text(script)
    mode = sys.argv[2]
    if mode not in ('executable', 'make-executable'):
        raise ValueError('unknown configure mode')
    if mode == 'make-executable':
        path = root / 'configure'
        if path.stat().st_nlink != 1:
            raise ValueError('aliased configure')
        path.chmod(path.stat().st_mode | 0o100)
