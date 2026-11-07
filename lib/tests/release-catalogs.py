"""Assert exact shipped/installed catalog bytes, plus NLS configure evidence."""
import hashlib
from pathlib import Path
import re
import sys
import tarfile

archive, output, domain = sys.argv[1:]
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
    stamps = [p for p in entries if p.name.endswith('/po/stamp-po')]
    assert len(stamps) == 1
    catalog_inputs = [p for p in entries if '/po/' in p.name and p.name.endswith(('.po', '.pot'))]
    assert all(p.mtime <= stamps[0].mtime for p in catalog_inputs), 'stamp-po regeneration required'
    assert shipped, 'empty shipped catalog set'
categories = ['LC_MESSAGES', 'LC_TIME'] if domain == 'coreutils' else ['LC_MESSAGES']
expected = {f'{language}/{category}/{domain}.mo': digest
            for language, digest in shipped.items() for category in categories}
installed = {str(p.relative_to(output / 'share/locale')): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (output / 'share/locale').rglob('*.mo')}
assert installed == expected, (set(installed) - set(expected), set(expected) - set(installed))
assert '#define ENABLE_NLS 1' in (output / 'nix-support/config.h').read_text()
gettext = (output / 'nix-support/gettext-libc').read_text().splitlines()
assert len(gettext) == 1 and re.fullmatch(r'gt_cv_func_gnugettext[0-9]+_libc=yes', gettext[0]), gettext
print(f'PASS {len(shipped)} shipped languages; {len(installed)} installed catalogs match')
