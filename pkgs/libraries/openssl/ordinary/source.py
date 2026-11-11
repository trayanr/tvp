"""Prepare only source scripts/make inputs; plan all mutations before writes."""
import os
from pathlib import Path
import re
import stat
import sys


def selected(path, data=b''):
    return (path.name in ('Configure', 'Makefile', 'Makefile.org', 'Makefile.in', 'Makefile.ssl')
            or path.name.endswith(('.sh', '.pl', '.pm', '.tmpl', '.pod'))
            or data.startswith(b'#!'))


def prepare(root, shell, perl, encoding="utf-8"):
    if encoding not in ("utf-8", "latin-1"):
        raise ValueError("unsupported declared source encoding")
    root = Path(root)
    if not root.is_absolute() or root != root.resolve(strict=True):
        raise ValueError('canonical source root required')
    for p in [root, *root.parents]:
        if not stat.S_ISDIR(p.lstat().st_mode):
            raise ValueError(('source parent is not a directory', p))
    for tool in [shell, perl]:
        if not tool.startswith('/nix/store/') or not os.access(tool, os.X_OK):
            raise ValueError(('missing explicit source interpreter', tool))
    changes, aliases, regular = {}, [], {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        for name in sorted(dirs + names):
            p = Path(directory)/name
            s = p.lstat()
            if stat.S_ISLNK(s.st_mode):
                aliases.append(p)
            elif stat.S_ISREG(s.st_mode):
                # No source hardlink has a reviewed alias role here.
                if s.st_nlink != 1:
                    raise ValueError(('source hardlink', p))
                regular[p] = p.read_bytes()
            elif not stat.S_ISDIR(s.st_mode):
                raise ValueError(('special source node', p))
    for p in aliases:
        q = p.resolve(strict=False)
        if os.path.isabs(os.readlink(p)) or not q.is_relative_to(root) or (q.exists() and q not in regular):
            raise ValueError(('escaping/directory source link', p))
        if selected(p, regular.get(q, b'')):
            # Old source trees expose Makefile.ssl through a direct sibling
            # Makefile link. Validate and edit that regular target only once.
            if not (p.name == 'Makefile' and os.readlink(p) == 'Makefile.ssl'
                    and p.with_name('Makefile.ssl') in regular):
                raise ValueError(('selected source symlink', p))
    diagnostic_makefile = (root/'crypto/Makefile').resolve(strict=False)
    for p, data in regular.items():
        relative = p.relative_to(root)
        # Text input selection is a semantic role, not a NUL/binary fallback.
        if not selected(p, data):
            continue
        if b'\0' in data:
            raise ValueError(('NUL in source script/template', relative))
        try:
            data.decode(encoding, errors='strict')
        except UnicodeError:
            raise ValueError(('source text violates declared encoding', relative, encoding)) from None
        updated = data
        if data.startswith(b'#!'):
            first, sep, body = data.partition(b'\n')
            match = re.fullmatch(rb'#![ \t]*(?:(?:/(?!.*(?:/env)[ \t])[^ \t]+/)|(?:(?:/usr)?/bin/env[ \t]+)|(?:\./))?(perl5?|sh|bash)([ \t]+-[ewTkxuf]+|[ \t]+-)?[ \t]*', first)
            if match:
                interpreter = perl if match[1] in (b'perl', b'perl5') else shell
                updated = b'#!' + interpreter.encode() + (match[2] or b'') + sep + body
            elif first == b'#!{- $config{hashbangperl} -}':
                pass  # Unified-build template, filled with HASHBANGPERL.
            elif b'perl' in first or re.search(rb'\b(?:sh|bash)\b', first):
                raise ValueError(('unsupported source interpreter form', relative, first))
        # Literal shell frontends in make templates/scripts, never an FHS lookup.
        updated = re.sub(rb'(?<![A-Za-z0-9_./-])/(?:usr/)?bin/(?:sh|bash)(?![A-Za-z0-9_./-])',
                         lambda _: shell.encode(), updated)
        # Diagnostic metadata must not retain the build-only compiler store
        # closure. Preserve every reported compiler option and its order.
        if p == diagnostic_makefile and not (root/'util/mkbuildinf.pl').exists():
            anchor = b'#define CFLAGS "$(CC) $(CFLAG)"'
            if updated.count(anchor) != 1:
                raise ValueError('historical compiler diagnostic anchor')
            updated = updated.replace(anchor, b'#define CFLAGS "$(notdir $(CC)) $(CFLAG)"')
        if relative == Path('util/mkbuildinf.pl'):
            anchor = b'$cflags = "compiler: $cflags";'
            if updated.count(anchor) != 1:
                raise ValueError('Perl compiler diagnostic anchor')
            updated = updated.replace(anchor, b"$cflags =~ s{^(?:/[^ /]+)+/([^ /]+)(?= |$)}{$1};\n" + anchor)
        if updated != data:
            changes[p] = updated
    for p, data in changes.items():
        p.write_bytes(data)
    return {'changed': [str(p.relative_to(root)) for p in changes], 'files': len(regular)}


if __name__ == '__main__':
    import json
    print(json.dumps(prepare(Path.cwd(), *sys.argv[1:]), sort_keys=True))
