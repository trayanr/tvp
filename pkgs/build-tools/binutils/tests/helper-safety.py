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
    target = owned/'ltmain.sh'
    target.symlink_to(sentinel)
    call('prepare.py', owned)
    target.unlink()
    target.mkdir()
    call('prepare.py', owned)
    target.rmdir()
    os.mkfifo(target)
    call('prepare.py', owned)
    target.unlink()
    target.write_text('eval "sys_lib_search_path=\\"$sys_lib_search_path_spec\\""\neval "sys_lib_dlsearch_path=\\"$sys_lib_dlsearch_path_spec\\""\n')
    os.utime(target, ns=(100000000000, 200000000000))
    call('prepare.py', owned, ok=True)
    assert target.stat().st_mtime_ns == 200000000000
    link = root/'linked-root'
    link.symlink_to(owned, target_is_directory=True)
    call('self-rpaths.py', link, ['/no/readelf', '/no/patchelf'])
    (owned/'bin').symlink_to(outside, target_is_directory=True)
    call('self-rpaths.py', owned, ['/no/readelf', '/no/patchelf'])
    assert sentinel.read_text() == 'untouched'
print('boundaries-ok')
