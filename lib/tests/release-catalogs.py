"""Assert exact shipped/installed catalog bytes, plus NLS configure evidence."""
import hashlib
from pathlib import Path
import sys
import tarfile

archive, output = sys.argv[1:]
output = Path(output)
with tarfile.open(archive) as source:
    entries = source.getmembers()
    shipped = {}
    for entry in entries:
        if '/po/' in entry.name and entry.name.endswith('.gmo'):
            language = Path(entry.name).stem
            po = next(p for p in entries if p.name == entry.name[:-4] + '.po')
            assert entry.mtime >= po.mtime, (entry.name, 'catalog regeneration required')
            shipped[language] = hashlib.sha256(source.extractfile(entry).read()).hexdigest()
    assert shipped, 'empty shipped catalog set'
installed = {}
for catalog in (output / 'share/locale').glob('*/LC_MESSAGES/*.mo'):
    language = catalog.parent.parent.name
    digest = hashlib.sha256(catalog.read_bytes()).hexdigest()
    # GNU Coreutils installs a second domain with the same shipped catalog.
    assert language in shipped and digest == shipped[language], catalog
    installed.setdefault(language, []).append(catalog)
assert set(installed) == set(shipped), (set(installed) - set(shipped), set(shipped) - set(installed))
assert '#define ENABLE_NLS 1' in (output / 'nix-support/config.h').read_text()
log = (output / 'nix-support/config.log').read_text()
assert 'GNU gettext in libc' in log
print(f'PASS {len(shipped)} shipped languages; {sum(map(len, installed.values()))} installed catalogs match')
