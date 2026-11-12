"""Exercise actual ELF/AR catalog slots with cached tools; no package build."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ordinary'))
from finalize import archive, catalog_slot, readonly_paths


def rejects(call):
    try:
        call()
    except ValueError:
        return
    raise AssertionError('unsupported catalog slot accepted')


def main(cc, readelf, ar):
    old = b'/nix/store/' + b'1' * 32 + b'-libxml2-2.15.3'
    new = b'/nix/store/' + b'2' * 32 + b'-libxml2-2.15.3'
    paths = [old + b'/etc/xml/catalog', old + b'/etc/sgml/catalog']
    accepted = paths + [b'file://' + path for path in paths]
    accepted += [b'\t         file://' + old
                 + b'/etc/xml/catalog are activated by default\n']
    for value in accepted:
        result = catalog_slot(value, old, new)
        assert result == value.replace(old, new) and len(result) == len(value)
    rejected = [
        old + b'/etc/xml/catalogue', old + b'/etc/xml/catalog/extra',
        old + b'/etc/../xml/catalog', old + b'/etc/other/catalog',
        b'http://' + paths[0], b'file:' + paths[0],
        b'unknown help ' + paths[0], b'file://' + paths[0] + b' trailing',
        b'\t         file://' + old + b'/etc/xml/catalog changed help\n',
    ]
    for value in rejected:
        rejects(lambda: catalog_slot(value, old, new))
    with tempfile.TemporaryDirectory(prefix='xml-catalog-slots-') as temporary:
        root = Path(temporary)
        source = root / 'catalog.c'
        source.write_text('const char *catalogs[] = {\n' + ',\n'.join(
            json.dumps(value.decode()) for value in accepted) + '\n};\n')
        obj, shared, static = root / 'catalog.o', root / 'catalog.so', root / 'catalog.a'
        subprocess.run([cc, '-O2', '-fPIC', '-c', str(source), '-o', str(obj)], check=True)
        subprocess.run([cc, '-shared', str(obj), '-o', str(shared)], check=True)
        subprocess.run([ar, 'rcD', str(static), str(obj)], check=True)
        for path in [obj, shared]:
            before = path.read_bytes()
            after, dynamic = readonly_paths(path, before, old, new, readelf,
                                             relocatable=path == obj)
            assert not dynamic and old not in after and new in after
            assert len(after) == len(before) and path.read_bytes() == before
        before = static.read_bytes()
        after = archive(before, old, new, readelf)
        assert len(after) == len(before) and old not in after and new in after
        assert static.read_bytes() == before
        # A recognized string in writable ELF data still cannot be relocated.
        source.write_text('char catalog[] = ' + json.dumps(paths[0].decode()) + ';\n')
        subprocess.run([cc, '-fPIC', '-shared', str(source), '-o', str(shared)], check=True)
        before = shared.read_bytes()
        rejects(lambda: readonly_paths(shared, before, old, new, readelf))
        assert shared.read_bytes() == before
    return {'acceptedShapes': len(accepted), 'rejectedShapes': len(rejected),
            'readonlyElfAndArchive': True, 'writableSlotRejected': True}


if __name__ == '__main__':
    print(json.dumps(main(*sys.argv[1:]), sort_keys=True))
