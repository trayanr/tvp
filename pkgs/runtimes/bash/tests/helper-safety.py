"""Bounded negative fixtures for the package's custom file writers."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

native, common = map(Path, sys.argv[1:3])

def call(script, root, extra=(), ok=False):
    result = subprocess.run([sys.executable, '-B', str(native/script), str(root), str(common), *map(str, extra)], capture_output=True)
    if (result.returncode == 0) != ok:
        raise AssertionError((script, result.returncode, result.stdout, result.stderr))

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    outside = root/'outside'
    outside.mkdir()
    sentinel = outside/'sentinel'
    sentinel.write_text('untouched')
    owned = root/'owned'
    owned.mkdir()
    (owned/'lib').symlink_to(outside, target_is_directory=True)
    call('self-helpers.py', owned, ['/declared/install'])
    (owned/'lib').unlink()
    (owned/'lib/bash').mkdir(parents=True)
    target = owned/'lib/bash/Makefile.inc'
    target.symlink_to(sentinel)
    call('self-helpers.py', owned, ['/declared/install'])
    target.unlink()
    target.mkdir()
    call('self-helpers.py', owned, ['/declared/install'])
    target.rmdir()
    target.write_text('INSTALL = /declared/install -c\n')
    os.utime(target, ns=(100000000000, 200000000000))
    call('self-helpers.py', owned, ['/declared/install'], ok=True)
    assert target.stat().st_mtime_ns == 200000000000
    assert 'INSTALL = install -c' in target.read_text()
    link = root/'linked-root'
    link.symlink_to(owned, target_is_directory=True)
    call('self-rpaths.py', link, ['/no/readelf', '/no/patchelf'])
    (owned/'bin').symlink_to(outside, target_is_directory=True)
    call('self-rpaths.py', owned, ['/no/readelf', '/no/patchelf'])
    assert sentinel.read_text() == 'untouched'
print('boundaries-ok')
