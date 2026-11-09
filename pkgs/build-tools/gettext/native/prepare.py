"""Adapt the shipped release, retaining generated-template timestamps.

Only regular owned source files are edited. No symlink traversal or regeneration.
"""
import json
import os
from pathlib import Path
import re
import sys

config = json.loads(sys.argv[1])
root = Path.cwd()


def change(path, transform):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'expected owned regular source: {path}')
    info = path.stat()
    if info.st_nlink != 1:
        raise ValueError(f'expected unlinked source: {path}')
    data = path.read_bytes()
    result = transform(data)
    if result != data:
        path.write_bytes(result)
    os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))


def replace(path, old, new):
    def operation(data):
        if old not in data:
            raise ValueError(f'{path}: missing release anchor {old!r}')
        return data.replace(old, new)
    change(root / path, operation)


prefix = os.environ['out'].encode()
replace('gettext-runtime/src/gettext.sh.in', b'  gettext ', b'  ' + prefix + b'/bin/gettext ')
replace('gettext-runtime/src/gettext.sh.in', b'  ngettext ', b'  ' + prefix + b'/bin/ngettext ')
replace('gettext-runtime/src/gettext.sh.in', b'envsubst ', b'"' + prefix + b'/bin/envsubst" ')
replace('gettext-tools/config.h.in', b'define BOURNE_SHELL "/bin/sh"',
        b'define BOURNE_SHELL "' + config['bash'].encode() + b'/bin/bash"')
replace('libtextstyle/configure', b"names_next_round='ncurses '", b"names_next_round='ncursesw '")
counts = {'shell': 0, 'perl': 0, 'python': 0, 'libtool': 0}
for directory, dirs, names in os.walk(root, followlinks=False):
    dirs[:] = [d for d in dirs if not (Path(directory) / d).is_symlink()]
    for name in names:
        path = Path(directory) / name
        if path.is_symlink():
            continue
        def adapt(data):
            first, newline, body = data.partition(b'\n')
            match = re.fullmatch(rb'#!\s*(?:/usr/bin/env\s+)?(?:[^\s]*/)?(sh|bash|perl|python3?)(\s.*)?', first)
            if match:
                interpreter = match[1].decode()
                role = 'shell' if interpreter in ('sh', 'bash') else 'perl' if interpreter == 'perl' else 'python'
                target = config['bash'] + '/bin/bash' if role == 'shell' else config[role] + '/bin/' + ('perl' if role == 'perl' else 'python3')
                first = b'#!' + target.encode() + (match[2] or b'')
                data = first + newline + body
                counts[role] += 1
            if name == 'ltmain.sh':
                # Do not let libtool discover host /lib and /usr/lib.
                search = b' '.join(f[2:].encode() for f in os.environ.get('NIX_LDFLAGS', '').split() if f.startswith('-L'))
                data, count = re.subn(rb'eval (sys_lib_search_path=).*', lambda m: m[1] + b"'" + search + b"'", data)
                if count != 1:
                    raise ValueError(f'{path}: libtool search anchor drift')
                data = re.sub(rb'eval sys_lib_.+search_path=.*', b'', data)
                counts['libtool'] += 1
            if name == 'configure':
                data = data.replace(b'/usr/bin/file', b'file')
            return data
        change(path, adapt)
assert all(counts.values()), counts
print('gettext source adaptations: ' + json.dumps(counts, sort_keys=True))
