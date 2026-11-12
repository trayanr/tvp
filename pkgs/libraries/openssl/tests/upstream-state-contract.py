"""Focused checkpoint and capture controls, without OpenSSL compilation."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


state = load('state', sys.argv[1])
classifier = load('classifier', sys.argv[2])
manifest = Path(sys.argv[3])
restore = load('restore', sys.argv[4])
restore.namespace = state.namespace
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    for protocol in json.loads(manifest.read_text())['protocols']:
        source = root / protocol
        source.mkdir()
        spec = json.loads(manifest.read_text())['protocols'][protocol]
        for name in spec['required']:
            p = source / name
            if name in ('Configure', 'Makefile'):
                p.write_text(str(source) + '\nprefix=/nix/store/production-prefix\n')
            else:
                p.mkdir()
        (source / 'apps/openssl').write_bytes(b'ELF\0historical source=' + str(source).encode())
        (source / 'apps/openssl').chmod(0o751)
        (source / 'libcrypto.so').write_bytes(b'ELF\0unchanged')
        (source / 'libcrypto.so.0').symlink_to('libcrypto.so')
        (source / 'test/fixture.pem').write_text('fixture')
        (source / '.git').mkdir(); (source / '.git/history').write_text('excluded')
        (source / 'temp.db').write_text('excluded')
        os.utime(source / 'apps/openssl', ns=(120123456789, 120123456789))
        epoch = root / 'epoch'; epoch.write_text('12345\n')
        checkpoint = root / (protocol + '-state')
        state.save(source, checkpoint, manifest, protocol, '/nix/store/production-prefix', epoch)
        layout = json.loads((checkpoint / 'layout.json').read_text())
        assert '.git/history' not in layout['members'] and 'temp.db' not in layout['members']
        workspace = root / (protocol + '-private'); workspace.mkdir()
        restore.restore(checkpoint, workspace)
        private = Path((workspace / 'tree-path').read_text().strip())
        assert private == workspace / 'source'
        assert (private / 'apps/openssl').stat().st_mtime_ns == 120123456789
        assert (private / 'apps/openssl').stat().st_mode & 0o777 == 0o751
        assert (private / 'apps/openssl').read_bytes() == (source / 'apps/openssl').read_bytes()
        assert (private / 'libcrypto.so.0').readlink() == Path('libcrypto.so')
        assert str(private) in (private / 'Makefile').read_text()
        assert 'prefix=/nix/store/production-prefix' in (private / 'Makefile').read_text()
        (private / 'test/private-marker').write_text('private')
        assert not (source / 'test/private-marker').exists()
        state.save(private, root / (protocol + '-T'), manifest, protocol, '/nix/store/production-prefix', epoch, True)
        second = root / (protocol + '-R'); second.mkdir()
        restore.restore(root / (protocol + '-T'), second)
        (source / 'outside').symlink_to('/nix/store')
        try:
            state.save(source, root / (protocol + '-bad'), manifest, protocol, 'prefix', epoch)
        except ValueError:
            pass
        else:
            raise AssertionError('external link accepted')
    raw = root / 'raw'; raw.mkdir()
    output = b'native workload output\n'
    (raw / 'output').write_bytes(output)
    def receipt(status):
        (raw / 'exit').write_text(str(status) + '\n')
        (raw / 'capture.json').write_text(json.dumps({'schema': 1, 'status': status,
            'bytes': len(output), 'sha256': hashlib.sha256(output).hexdigest()}))
    receipt(0); classifier.accept(raw)
    for kind in ('nonzero', 'malformed', 'truncated', 'missing', 'boolean'):
        receipt(0); (raw / 'output').write_bytes(output)
        if kind == 'nonzero': receipt(1)
        if kind == 'malformed': (raw / 'exit').write_text('00\n')
        if kind == 'truncated': (raw / 'output').write_bytes(b'partial')
        if kind == 'boolean':
            data = json.loads((raw / 'capture.json').read_text()); data['status'] = False
            (raw / 'capture.json').write_text(json.dumps(data))
        if kind == 'missing': (raw / 'capture.json').unlink()
        try:
            classifier.accept(raw)
        except (ValueError, FileNotFoundError):
            pass
        else:
            raise AssertionError('invalid capture accepted: ' + kind)
print('Five checkpoint protocols and strict capture controls passed')
