"""Compare both stages to every pinned rust-std component payload file."""
import hashlib
from pathlib import Path
import sys
import tarfile
archive, artifact, final = sys.argv[1:]
count = 0
expected_paths = set()
suffixes = set()
with tarfile.open(archive) as source:
    prefix = 'rust-1.97.1-x86_64-unknown-linux-gnu/rust-std-x86_64-unknown-linux-gnu/'
    for member in source:
        if not member.name.startswith(prefix) or not member.isfile():
            continue
        relative = member.name[len(prefix):]
        if relative == 'manifest.in':
            continue
        if not relative.startswith('lib/rustlib/x86_64-unknown-linux-gnu/lib/'):
            raise ValueError('unexpected target component scope')
        expected_paths.add(relative)
        expected = hashlib.sha256(source.extractfile(member).read()).digest()
        for output in [artifact, final]:
            path = Path(output) / relative
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).digest() != expected:
                raise ValueError(f'target payload changed: {path}')
        suffixes.add(Path(relative).suffix)
        count += 1
if count < 60 or not {'.rlib', '.rmeta', '.a', '.so'} <= suffixes:
    raise ValueError('incomplete target inventory')
for output in [artifact, final]:
    library = Path(output) / 'lib/rustlib/x86_64-unknown-linux-gnu/lib'
    if {str(p.relative_to(output)) for p in library.iterdir()} != expected_paths:
        raise ValueError('target library membership changed')
with tarfile.open(archive) as source:
    prefix = 'rust-1.97.1-x86_64-unknown-linux-gnu/rustc/'
    for member in source:
        if not member.name.startswith(prefix) or not member.isfile():
            continue
        relative = member.name[len(prefix):]
        # Host shared libraries, LLVM linker script, debugger resources/schema.
        # Executable host roles and installer metadata are intentional edits.
        if not (relative.startswith(('etc/', 'lib/rustlib/etc/')) or
                (relative.startswith('lib/') and relative.count('/') == 1)):
            continue
        expected = hashlib.sha256(source.extractfile(member).read()).digest()
        for output in [artifact, final]:
            path = Path(output) / relative
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).digest() != expected:
                raise ValueError(f'compiler resource changed: {path}')
print('pinned target payload preserved')
