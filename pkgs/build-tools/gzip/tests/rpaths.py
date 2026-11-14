"""Exercise artifact-prefix relocation without interpreting ELF loader syntax."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

relocator, installed_tree, patchelf, seed = sys.argv[1:]
# The common producer uses equal-width artifact/final names.
# Generate each old prefix after the private output spelling is known.
old_marker = b'@ARTIFACT@'
cases = [
    b'$ORIGIN/../lib:$LIB/../$PLATFORM::/runtime/link/../lib:',
    old_marker + b'///lib/../other:$ORIGIN/../lib::',
    None,
]
for index, value in enumerate(cases):
    root = (Path.cwd() / 'ordinary-rpaths' / str(index)).resolve()
    root.mkdir(parents=True)
    elf = root / 'probe'
    shutil.copyfile(seed, elf)
    elf.chmod(0o755)
    new = os.fsencode(root)
    old = b"/nix/store/" + b"a" * (len(new) - len(b"/nix/store/"))
    assert len(new) == len(old)
    raw = value.replace(old_marker, old) if value is not None else new + b'//lib:$ORIGIN/../lib'
    subprocess.run([patchelf, '--set-rpath', raw, str(elf)], check=True)
    subprocess.run([sys.executable, '-B', relocator, str(root), old, "{}", installed_tree], check=True)
    actual = subprocess.check_output([patchelf, '--print-rpath', str(elf)]).removesuffix(b'\n')
    assert actual == raw.replace(old, new), (raw, actual)
print('three loader-path cases passed')
