"""Bounded negative fixtures for the package's custom file writers."""
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile

native, common = map(Path, sys.argv[1:3])
binary, readelf, patchelf = map(Path, sys.argv[3:6])

def call(script, root, extra=(), ok=False, message=None):
    result = subprocess.run([sys.executable, '-B', str(native/script), str(root), str(common), *map(str, extra)], capture_output=True)
    if (result.returncode == 0) != ok:
        raise AssertionError((script, result.returncode, result.stdout, result.stderr))
    if message is not None:
        assert message in result.stderr, result.stderr


def metadata(path):
    info = path.stat()
    return (info.st_dev, info.st_ino, info.st_mode, info.st_nlink,
            info.st_size, info.st_atime_ns, info.st_mtime_ns, info.st_ctime_ns)


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
    external_text = outside/'text-hardlink'
    os.link(target, external_text)
    original_text = target.read_bytes()
    # Reset atime after obtaining the expected bytes so reads cannot hide a change.
    os.utime(target, ns=(100000000000, 200000000000))
    before = metadata(external_text)
    call('prepare.py', owned, (), message=b'hardlink')
    assert metadata(external_text) == before
    assert external_text.read_bytes() == original_text
    external_text.unlink()
    call('prepare.py', owned, ok=True)
    assert target.stat().st_mtime_ns == 200000000000
    link = root/'linked-root'
    link.symlink_to(owned, target_is_directory=True)
    call('self-rpaths.py', link, ['/no/readelf', '/no/patchelf'])
    (owned/'bin').symlink_to(outside, target_is_directory=True)
    call('self-rpaths.py', owned, ['/no/readelf', '/no/patchelf'])
    # One unsafe alias must reject the entire pass before an earlier ELF is read.
    elf_root = root/'elf-owned'
    (elf_root/'bin').mkdir(parents=True)
    (elf_root/'lib').mkdir()
    earlier = elf_root/'bin/a-regular'
    linked = elf_root/'bin/z-linked'
    shutil.copyfile(binary, earlier)
    shutil.copyfile(binary, linked)
    external_elf = outside/'elf-hardlink'
    os.link(linked, external_elf)
    original_elf = binary.read_bytes()
    for path in (earlier, linked):
        os.utime(path, ns=(100000000000, 200000000000))
    before_earlier, before_external = metadata(earlier), metadata(external_elf)
    call('self-rpaths.py', elf_root, [readelf, patchelf], message=b'hardlink')
    assert metadata(earlier) == before_earlier
    assert metadata(external_elf) == before_external
    assert earlier.read_bytes() == original_elf
    assert external_elf.read_bytes() == original_elf
    linked.unlink()
    external_elf.unlink()

    # Legitimate aliases elsewhere inside the prefix share the transformed ELF.
    (elf_root/'aliases').mkdir()
    alias = elf_root/'aliases/native'
    os.link(earlier, alias)
    call('self-rpaths.py', elf_root, [readelf, patchelf], ok=True)
    for path in (earlier, alias):
        result = subprocess.run([str(patchelf), '--print-rpath', str(path)],
                                capture_output=True, check=True)
        assert str(elf_root/'lib') in result.stdout.decode().strip().split(':')
    parent_link = root/'linked-parent'
    parent_link.symlink_to(root, target_is_directory=True)
    call('self-rpaths.py', parent_link/'elf-owned', [readelf, patchelf])
    assert sentinel.read_text() == 'untouched'
print('boundaries-ok')
