"""Tiny byte/path fixtures; no package, toolchain or ELF construction."""
import importlib.util
import os
from pathlib import Path
import tempfile
import sys

spec = importlib.util.spec_from_file_location(
    'relocation', Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parents[2] / 'pkgs/libraries/jdk-support-relocate.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary) / 'final'
    evidence = Path(temporary) / 'evidence-final'
    root.mkdir()
    evidence.mkdir()
    new = os.fsencode(root)
    old = new.replace(b'final', b'prior')
    new_evidence = os.fsencode(evidence)
    old_evidence = new_evidence.replace(b'evidence-final', b'evidence-prior')
    pairs = [(old, new), (old_evidence, new_evidence)]
    dependency = b'/nix/store/foreign-freetype-provider/lib'
    binary = root / 'compiled-self'
    # Model a compiled NUL string followed by its recorded length and offset.
    trailer = len(old).to_bytes(4, 'little') + b'\x10\0\0\0'
    payload = b'\x7fELF\0' + old + b'/etc/fonts\0' + trailer + old + b'/var/cache/fontconfig\0' + dependency
    binary.write_bytes(payload)
    binary.chmod(0o755)
    os.utime(binary, ns=(1000000000, 1000000000))
    alias = root / 'hardlink'
    os.link(binary, alias)
    link = root / 'link'
    link.symlink_to(os.fsdecode(old) + '/compiled-self')
    (root / 'metadata.pc').write_bytes(b'prefix=' + old + b'\nforeign=' + dependency)
    (evidence / 'build.log').write_bytes(old + b'\n' + old_evidence + b'\n')
    module.relocate([root, evidence], pairs)
    assert binary.read_bytes() == payload.replace(old, new)
    assert trailer in binary.read_bytes()
    assert binary.stat().st_ino == alias.stat().st_ino
    assert binary.stat().st_mtime_ns == 1000000000
    assert binary.stat().st_mode & 0o777 == 0o755
    assert os.readlink(link) == os.fsdecode(new) + '/compiled-self'
    assert (root / 'metadata.pc').read_bytes() == b'prefix=' + new + b'\nforeign=' + dependency
    assert (evidence / 'build.log').read_bytes() == new + b'\n' + new_evidence + b'\n'
    # Refuse every unequal-width mapping before touching even the first file.
    before = binary.read_bytes()
    try:
        module.relocate([root], [(new, old), (old_evidence, b'short')])
    except ValueError:
        pass
    else:
        raise AssertionError('unequal-width compiled relocation accepted')
    assert binary.read_bytes() == before
print('PASS: compiled widths, config/cache roots, dependency preservation, named evidence, links, modes, times, rejection')
