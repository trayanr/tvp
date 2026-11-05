"""Negative controls for the exact installed Ninja data allowance."""
import importlib
from pathlib import Path
import shutil
import sys
import tempfile

observer = importlib.import_module('source-build-tool-runtime-audit')
root, archive = map(Path, sys.argv[1:])
with tempfile.TemporaryDirectory() as tmp:
    copy = Path(tmp) / 'ninja'
    shutil.copytree(root, copy)
    copy.chmod(0o755)
    for p in copy.rglob('*'):
        if p.is_dir(): p.chmod(0o755)
        if p.is_file(): p.chmod(0o644 if 'share' in p.parts else 0o755)
    assert len(observer.ninja_data(copy, archive)) == 3
    module = copy / 'share/ninja/ninja_syntax.py'
    module.chmod(0o755)
    try: observer.ninja_data(copy, archive)
    except ValueError: pass
    else: raise AssertionError('Executable source data accepted')
    module.chmod(0o644)
    injected = copy / 'share/ninja/injected'
    injected.write_bytes(b'\x7fELF')
    try: observer.ninja_data(copy, archive)
    except ValueError: pass
    else: raise AssertionError('Arbitrary extra ELF accepted')
    injected.unlink()
    original = module.read_bytes()
    module.write_bytes(b'#!/usr/bin/env python3\n' + original)
    try: observer.ninja_data(copy, archive)
    except ValueError: pass
    else: raise AssertionError('Foreign script accepted')
    module.write_bytes(original)
    module.unlink(); module.symlink_to(root / 'share/ninja/ninja_syntax.py')
    try: observer.ninja_data(copy, archive)
    except ValueError: pass
    else: raise AssertionError('Data symlink accepted')
print('PASS: exact source data; reject executable mode, added ELF, foreign script, symlink')
