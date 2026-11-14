"""The two installed Ruby manuals, normalized with selected gzip -c -n."""
import gzip
import os
from pathlib import Path
import stat
import subprocess
import sys

root = Path(sys.argv[1])
if not root.is_absolute() or root.is_symlink() or not root.is_dir():
    raise ValueError("expected owned output")
directory = root
for component in ("share", "man", "man1"):
    directory /= component
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError(f"unsafe manual directory: {directory}")
for name in ("erb.1", "ruby.1"):
    plain, target = directory / name, directory / (name + ".gz")
    # rbinstall probes gzip even for MANTYPE=man. Accept only one known form.
    if plain.is_symlink():
        raise ValueError(f"symlink manual: {plain}")
    compressed = not plain.exists()
    source = target if compressed else plain
    if not compressed and (target.exists() or target.is_symlink()):
        raise ValueError(f"duplicate installed manual: {plain}")
    info = source.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError(f"expected unlinked regular manual: {source}")
    data = source.read_bytes()
    if compressed:
        data = gzip.decompress(data)
    result = subprocess.run([sys.argv[2], "-c", "-n"], input=data,
                            check=True, stdout=subprocess.PIPE)
    # Tool failure leaves the installed manual untouched.
    with target.open("wb" if compressed else "xb") as stream:
        stream.write(result.stdout)
    os.chmod(target, stat.S_IMODE(info.st_mode))
    os.utime(target, ns=(info.st_atime_ns, info.st_mtime_ns))
    if not compressed:
        source.unlink()
