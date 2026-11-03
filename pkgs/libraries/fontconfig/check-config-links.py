"""Validate Meson's default config links against the installed template tree."""
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
links = root / 'etc/fonts/conf.d'
templates = root / 'share/fontconfig/conf.avail'
assert links.is_dir() and templates.is_dir()
assert (root / 'etc/fonts/fonts.conf').is_file()
assert (root / 'share/xml/fontconfig/fonts.dtd').is_file()
assert (root / 'var/cache/fontconfig').is_dir()
found = 0
for path in links.iterdir():
    if path.is_symlink():
        assert os.readlink(path) == '../../../share/fontconfig/conf.avail/' + path.name, path
        assert path.resolve(strict=True) == templates / path.name, path
        found += 1
assert found > 0
