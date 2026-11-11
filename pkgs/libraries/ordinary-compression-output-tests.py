"""ELF inspection failures must leave the complete copied output unchanged."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

helper, readelf, patchelf, dynamic, static, relocatable = sys.argv[1:]
top = Path.cwd() / 'inspection-fixtures'
top.mkdir()
old = b'/nix/store/' + b'a' * 32 + b'-artifact-inspection-regression' * 5

def tool(name, status):
    path = top / name
    path.write_text('#!' + sys.executable + '\nimport sys\n'
                    'print("selected-inspection-diagnostic", file=sys.stderr)\n'
                    'sys.exit(' + str(status) + ')\n')
    path.chmod(0o755)
    return str(path)

failed = tool('failed', 42)
warning = tool('warning', 0)

def fixture(name, seed):
    root = top / name
    root.mkdir()
    (root / 'a-text').write_bytes(old + b'/metadata\n')
    elf = root / 'z-elf'
    shutil.copyfile(seed, elf)
    elf.chmod(0o755)
    with elf.open('ab') as stream:
        stream.write(old + b'\0')
    return root

def snapshot(root):
    return {p.name: p.read_bytes() for p in root.iterdir()}

def relocate(root, elf_tool, rpath_tool):
    config = {'family': 'zlib', 'readelf': elf_tool}
    return subprocess.run([sys.executable, '-B', helper, str(root), old,
                           rpath_tool, json.dumps(config)], capture_output=True)

for name, elf_tool, rpath_tool in [
        ('failed-patchelf', readelf, failed),
        ('warning-patchelf', readelf, warning),
        ('failed-readelf', failed, patchelf),
        ('warning-readelf', warning, patchelf)]:
    root = fixture(name, dynamic)
    before = snapshot(root)
    result = relocate(root, elf_tool, rpath_tool)
    assert result.returncode and b'selected-inspection-diagnostic' in result.stderr, result
    assert snapshot(root) == before, name

# Static executables and ET_REL files are deliberately not sent to Patchelf.
for name, seed in [('static', static), ('relocatable', relocatable)]:
    root = fixture(name, seed)
    result = relocate(root, readelf, failed)
    assert result.returncode == 0, result.stderr
    assert all(old not in data for data in snapshot(root).values())
    if name == 'static':
        subprocess.run([str(root / 'z-elf')], check=True)

root = fixture('loader-tokens', dynamic)
elf = root / 'z-elf'
original = subprocess.check_output([patchelf, '--print-rpath', dynamic]).removesuffix(b'\n')
rpath = b'$ORIGIN/../lib:$LIB/../$PLATFORM::' + old + b'///lib/../other:' + original
subprocess.run([patchelf, '--set-rpath', rpath, str(elf)], check=True)
result = relocate(root, readelf, patchelf)
assert result.returncode == 0, result.stderr
actual = subprocess.check_output([patchelf, '--print-rpath', str(elf)]).removesuffix(b'\n')
assert actual == rpath.replace(old, os.fsencode(root)), (rpath, actual)
subprocess.run([str(elf)], check=True)

root = fixture('malformed', dynamic)
(root / 'z-elf').write_bytes(b'\x7fELFtruncated' + old)
before = snapshot(root)
assert relocate(root, readelf, patchelf).returncode
assert snapshot(root) == before
print('inspection-contracts')
