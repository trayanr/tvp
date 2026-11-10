"""Keep upstream host-library bytes and satisfy their self RPATH explicitly.

The BOLT-processed rustc_driver carries a stale local section-symbol index which
patchelf warns about when growing its dynamic string table. No symbol rewriting,
stripping or warning exception is needed: upstream's $ORIGIN/../lib is valid.
Only these shallow host libraries use this operation; never the target sysroot.
"""
import os
from pathlib import Path
import sys
sys.path.insert(0, sys.argv[3])
from common import elf, invocation, store_directories, tool

root, config = invocation()
providers = store_directories(config['libraries'])
expected = {'libdl.so.2', 'libgcc_s.so.1', 'librt.so.1', 'libpthread.so.0',
            'libc.so.6', 'libm.so.6', 'libz.so.1', 'ld-linux-x86-64.so.2'}
needed = set()
for path in sorted((root / 'lib').iterdir()):
    if path.is_dir():
        continue
    if path.is_symlink() or path.stat().st_nlink != 1:
        raise ValueError(f'unsupported host library inode: {path}')
    kind = elf(path, config['readelf'])
    if kind is None and path.name == 'libLLVM-22-rust-1.97.1-stable.so' and path.read_bytes() == b'INPUT(libLLVM.so.22.1-rust-1.97.1-stable)\n':
        continue  # Upstream's exact linker script is a compiler resource.
    if kind is None or not kind[0]:
        raise ValueError(f'expected host shared ELF: {path}')
    if tool(config['patchelf'], '--print-rpath', path).strip() != '$ORIGIN/../lib':
        raise ValueError('pinned host self RPATH changed')
    needed.update(tool(config['patchelf'], '--print-needed', path).splitlines())
external = {name for name in needed if not (root / 'lib' / name).is_file()}
if external != expected:
    raise ValueError(f'host runtime inventory changed: {external ^ expected}')
links = []
for name in sorted(external):
    matches = [Path(p) / name for p in providers if (Path(p) / name).is_file()]
    if len(matches) != 1:
        raise ValueError(f'expected one declared provider for {name}: {matches}')
    links.append((name, matches[0]))
for name, provider in links:
    os.symlink(str(provider), root / 'lib' / name)
