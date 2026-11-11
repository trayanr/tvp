"""Bind an inspected neutral ZIP container without reconstructing its archive."""
import io
from pathlib import Path
import stat
import sys
import zipfile


def bind(root, interpreter):
    if (not root.is_absolute() or root.is_symlink() or not root.is_dir()
            or not interpreter.startswith('/') or any(c in interpreter for c in '\0\r\n \t')):
        raise ValueError('expected owned root and absolute direct interpreter')
    # The complete target plan is checked before writing. Never follow parents,
    # a linked leaf, external hardlinks, or a special file.
    directory = root / 'libexec'
    if not stat.S_ISDIR(directory.lstat().st_mode):
        raise ValueError('expected real libexec directory')
    path = directory / 'meson.pyz'
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError('expected unlinked regular zipapp')
    data = path.read_bytes()
    if not data.startswith(b'PK\x03\x04'):
        raise ValueError('expected neutral ZIP header, not an interpreter frontend')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        entries = archive.infolist()
        if (not any(i.filename == '__main__.py' for i in entries)
                or not any(i.filename == 'mesonbuild/coredata.py' for i in entries)
                or any(i.compress_type != zipfile.ZIP_DEFLATED for i in entries if not i.is_dir())
                or archive.testzip() is not None):
            raise ValueError('expected intact compressed Meson zipapp')
    path.write_bytes(b'#!' + interpreter.encode() + b'\n' + data)
    path.chmod(0o755)


if __name__ == '__main__':
    bind(Path(sys.argv[1]), sys.argv[2])
