"""Validate the pinned Rust host roles and detach only owned internal hardlinks.

No sysroot library is a host tool. Alias basenames remain real installed paths:
LLD uses argv[0] to choose its ELF/COFF/Mach-O/Wasm driver.
"""
import os
from pathlib import Path
import stat
import sys
import tempfile

root = Path(sys.argv[1]).resolve(strict=True)
triple = 'x86_64-unknown-linux-gnu'
roles = {
    'bin': {'rustc', 'rustdoc', 'rust-gdb', 'rust-gdbgui', 'rust-lldb'},
    'lib': {'libLLVM-22-rust-1.97.1-stable.so', 'libLLVM.so.22.1-rust-1.97.1-stable',
            'librustc_driver-832cf6cfb1386559.so'},
    'libexec': {'rust-analyzer-proc-macro-srv'},
    f'lib/rustlib/{triple}/bin': {'rust-lld', 'rust-objcopy', 'wasm-component-ld'},
    f'lib/rustlib/{triple}/bin/gcc-ld': {'ld.lld', 'ld64.lld', 'lld-link', 'wasm-ld'},
}
selected = set()
for directory, expected in roles.items():
    parent = root / directory
    if parent.is_symlink() or not parent.is_dir():
        raise ValueError(f'invalid host role: {directory}')
    actual = {p.name for p in parent.iterdir() if not p.is_dir()}
    if actual != expected:
        raise ValueError(f'host inventory differs for {directory}: {actual ^ expected}')
    selected.update(parent / name for name in expected)
inodes = {}
for parent, dirs, names in os.walk(root, followlinks=False):
    for name in names:
        p = Path(parent) / name
        info = p.lstat()
        if stat.S_ISREG(info.st_mode):
            inodes.setdefault((info.st_dev, info.st_ino), []).append(p)
for p in sorted(selected):
    info = p.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError(f'host tool must be a regular file: {p}')
    aliases = inodes[(info.st_dev, info.st_ino)]
    if info.st_nlink != len(aliases) or not set(aliases) <= selected:
        raise ValueError(f'external or cross-role hardlink: {p}')
# Validate the entire inventory before replacing any owned inode.
for p in sorted(selected):
    info = p.stat()
    if info.st_nlink > 1:
        with tempfile.NamedTemporaryFile(dir=p.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(p.read_bytes())
        temporary.chmod(stat.S_IMODE(info.st_mode))
        os.utime(temporary, ns=(info.st_atime_ns, info.st_mtime_ns))
        os.replace(temporary, p)
print('validated Rust host inventory; aliases retain their basenames')
