"""Port the pinned 1998 expected listing before the upstream comparison."""
import hashlib
import os
from pathlib import Path
import stat
import tempfile


ORIGINAL_SHA256 = 'c3eac0fc28adaf8a89bcf36fda3963e37498878031ae512361f43eac88436b59'
PORTED_SHA256 = 'b73d4cf2d5af2f50806317eebd84a8626afb0ab8f3d1ecb5272720b6f012be77'


def port_expected(data):
    if hashlib.sha256(data).hexdigest() != ORIGINAL_SHA256:
        raise ValueError('unexpected original zipinfo fixture')
    header = b'Archive:  testmake.zip   527 bytes   2 files\n'
    if data.count(header) != 1 or data.count(b'19-Nov-98') != 2:
        raise ValueError('unexpected original fixture fields')
    result = data.replace(header, b'Archive:  testmake.zip\nZip file size: 527 bytes, number of entries: 2\n')
    result = result.replace(b'19-Nov-98', b'98-Nov-19')
    if hashlib.sha256(result).hexdigest() != PORTED_SHA256:
        raise ValueError('unexpected ported zipinfo fixture')
    return result


def prepare(directory):
    fixture = directory / 'testmake.zipinfo'
    initial = fixture.lstat()
    if not stat.S_ISREG(initial.st_mode) or initial.st_nlink != 1:
        raise ValueError('expected private regular zipinfo fixture')
    with os.fdopen(os.open(fixture, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as source:
        info = os.fstat(source.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1
                or (info.st_dev, info.st_ino) != (initial.st_dev, initial.st_ino)):
            raise ValueError('expected private regular zipinfo fixture')
        original = source.read()
    ported = port_expected(original)
    receipts = [
        (directory / 'upstream-zipinfo.original', original),
        (directory / 'upstream-zipinfo.expected', ported),
    ]
    for path, _ in receipts:
        if os.path.lexists(path):
            raise ValueError('fixture receipt already exists')
    staged = []
    try:
        for path, data in receipts + [(fixture, ported)]:
            fd, name = tempfile.mkstemp(prefix='.tvp-unzip-fixture-', dir=directory)
            temporary = Path(name)
            staged.append((temporary, path))
            with os.fdopen(fd, 'wb') as target:
                target.write(data)
                os.fchmod(target.fileno(), stat.S_IMODE(info.st_mode))
        # All validation precedes replacement; the actual listing is not read.
        for temporary, path in staged:
            os.replace(temporary, path)
        os.utime(fixture, ns=(info.st_atime_ns, info.st_mtime_ns))
    finally:
        for temporary, _ in staged:
            temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    prepare(Path.cwd())
