"""Relocate installed PHP prefixes, including compiled CLI/CGI path constants.

PHP embeds its prefix in ELF strings as well as php-config, phpize, headers,
manuals and phar launchers. The recipe selects equal-width A/F store names.
"""
import hashlib
import os
from pathlib import Path
import sys

def relocate_phar(data, old, new):
    """Relocate the loader while preserving archive contents and signature type."""
    if not data.endswith(b'GBMB'):
        return data.replace(old, new)
    kind = int.from_bytes(data[-8:-4], 'little')
    algorithm = {1: 'md5', 2: 'sha1', 3: 'sha256', 4: 'sha512'}.get(kind)
    if algorithm is None:
        raise ValueError('PHP PHAR relocation requires a supported hash signature')
    size = hashlib.new(algorithm).digest_size
    if len(data) < size + 8:
        raise ValueError('truncated PHP PHAR signature')
    body, signature = data[:-size-8], data[-size-8:-8]
    if hashlib.new(algorithm, body).digest() != signature:
        raise ValueError('invalid original PHP PHAR signature')
    loader, marker, payload = body.partition(b'__HALT_COMPILER();')
    if not marker or old in payload:
        raise ValueError('PHP PHAR prefix relocation must affect only its loader')
    relocated = loader.replace(old, new) + marker + payload
    return relocated + hashlib.new(algorithm, relocated).digest() + data[-8:]


def main(root, old):
    new = str(root).encode()
    if len(old) != len(new):
        raise ValueError('PHP compiled prefix relocation requires equal-width store names')
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            target = os.readlink(path)
            if old.decode() in target:
                path.unlink()
                path.symlink_to(target.replace(old.decode(), new.decode()))
        elif path.is_file():
            data = path.read_bytes()
            if old in data:
                relocated = (relocate_phar(data, old, new)
                             if path.relative_to(root) == Path('bin/phar.phar')
                             else data.replace(old, new))
                times = path.stat()
                path.write_bytes(relocated)
                os.utime(path, ns=(times.st_atime_ns, times.st_mtime_ns))


if __name__ == '__main__':
    main(Path(sys.argv[1]), os.environ['TVP_ARTIFACT_ROOT'].encode())
