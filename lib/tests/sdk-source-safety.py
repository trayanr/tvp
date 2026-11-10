"""Local source namespace and template negative controls; no Nix realization."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

repo = Path(sys.argv[1]).resolve(strict=True)
spec = importlib.util.spec_from_file_location('archive', repo / 'lib/sources/validate-archive.py')
archive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive)
count = 0
with tempfile.TemporaryDirectory(prefix='sdk-source-safety-') as tmp:
    root = Path(tmp)
    for entries, accepted in [
        ([('alpha', 'file', ''), ('nested/beta', 'file', '')], True),
        ([('top/link', 'symlink', '../alpha'), ('alpha', 'file', '')], True),
        ([('top/a', 'file', ''), ('other/b', 'file', '')], True),
        ([('link', 'symlink', 'nested/beta'), ('nested/beta', 'file', '')], True),
        ([('../escape', 'file', '')], False),
        ([('/escape', 'file', '')], False),
        ([('link', 'symlink', '../escape')], False),
        ([('link', 'symlink', '/tmp')], False),
        ([('link', 'symlink', '.'), ('link/escape', 'file', '')], False),
        ([('a', 'file', ''), ('a', 'file', '')], False),
        ([('a', 'hardlink', 'outside')], False),
        ([('a', 'fifo', '')], False),
        ([('a', 'symlink', '.'), ('b', 'symlink', 'a/../outside')], False),
    ]:
        path = root / 'fixture.tar.gz'
        with tarfile.open(path, 'w:gz') as stream:
            for name, kind, target in entries:
                item = tarfile.TarInfo(name)
                item.type = {'file': tarfile.REGTYPE, 'symlink': tarfile.SYMTYPE,
                             'hardlink': tarfile.LNKTYPE, 'fifo': tarfile.FIFOTYPE}[kind]
                item.linkname = target
                stream.addfile(item, io.BytesIO(b''))
        try:
            archive.validate(path)
            success = True
        except ValueError:
            success = False
        assert success == accepted, (entries, accepted)
        count += 1
    owned = root / 'owned'
    owned.mkdir()
    (owned / 'bin').mkdir()
    template = root / 'template'
    template.write_text('#!@bash@\nexec @program@\n')
    config = {'path': 'bin/test', 'template': str(template),
              'values': {'bash': '/selected/bash', 'program': '@OUTPUT@/program'}}
    def render(value):
        return subprocess.run([sys.executable, '-B', str(repo / 'lib/sdk-output/template.py'),
                               str(owned), json.dumps(value), str(repo / 'lib/native-output'),
                               str(repo / 'lib/output-tools')], capture_output=True)
    assert render(config).returncode == 0
    expected = f'#!/selected/bash\nexec {owned}/program\n'
    assert (owned / 'bin/test').read_text() == expected
    assert render(config).returncode != 0  # Existing destination/hardlink rejected.
    (owned / 'bin/test').unlink()
    bad = config | {'values': {'bash': '/selected/bash'}}
    assert render(bad).returncode != 0 and not (owned / 'bin/test').exists()
    outside = root / 'outside'
    outside.write_text('protected')
    os.link(outside, owned / 'bin/test')
    assert render(config).returncode != 0 and outside.read_text() == 'protected'
    (owned / 'bin/test').unlink()
    (owned / 'bin').rmdir()
    (owned / 'bin').symlink_to(root, target_is_directory=True)
    assert render(config).returncode != 0 and not (root / 'test').exists()
    count += 5
    source_root = root / 'source'
    for directory in ['tools', 'build/config', 'runtime/tools', 'third_party']:
        (source_root / directory).mkdir(parents=True, exist_ok=True)
    payload = root / 'payload'
    payload.mkdir()
    (payload / 'file').write_text('payload')
    def prepare(entries):
        return subprocess.run([sys.executable, '-B', str(repo / 'pkgs/runtimes/dart/native/prepare.py'),
                               json.dumps(entries), '[]', str(repo / 'lib/native-output')],
                              cwd=source_root, capture_output=True)
    entry = {'path': 'third_party/dependency', 'src': str(payload)}
    assert prepare([entry]).returncode == 0
    assert (source_root / 'third_party/dependency/file').read_text() == 'payload'
    assert prepare([entry | {'path': '../escape'}]).returncode != 0
    assert prepare([entry, entry]).returncode != 0
    target = source_root / 'third_party/dependency/file'
    target.unlink()
    target.symlink_to(outside)
    assert prepare([entry]).returncode != 0 and outside.read_text() == 'protected'
    target.unlink()
    os.link(outside, target)
    assert prepare([entry]).returncode != 0 and outside.read_text() == 'protected'
    target.unlink()
    os.link(outside, source_root / 'tools/shared-script')
    assert prepare([]).returncode != 0 and outside.read_text() == 'protected'
    count += 6
print(json.dumps({'passed': count, 'archive': 'root-preserving/special/link/traversal/duplicate',
                  'template': 'effective-values/no-partial-write/symlink-parent/hardlink'}))
