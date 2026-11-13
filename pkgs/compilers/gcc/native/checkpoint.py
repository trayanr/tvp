"""Production active-stage checkpoint. No test preparation or build dispatch.

Retain patched source and active build prerequisites, excluding obsolete stage
object directories. Stage2 hashes/compare/configure/install provenance stays in
production. Exact check-target sufficiency and size require later qualification.
"""
import json
import os
from pathlib import Path
import sys
import tarfile


def selected(name):
    parts = Path(name).parts
    return parts[0] == 'source' or (parts[0] == 'build' and not (
        len(parts) > 1 and (parts[1] == 'install-root' or
        (parts[1].startswith(('stage1-', 'stage2-', 'prev-')) and parts[1] not in ('stage1-start','stage2-start','stage1-bubble','stage2-bubble','stage1-lean','stage2-lean')))))


def save(root, dest):
    if not root.is_absolute() or root.resolve() != root or dest.exists():
        raise ValueError('private checkpoint roots required')
    required = ['source/gcc/testsuite', 'build/Makefile', 'build/stage_final',
                'build/gcc/xgcc', 'build/gcc/cc1', 'build/gcc/cc1plus']
    for name in required:
        if not (root/name).exists():
            raise ValueError(('missing active checkpoint prerequisite', name))
    entries = []
    links = {}
    for top in ('source', 'build'):
        if (root/top).is_symlink() or not (root/top).is_dir():
            raise ValueError(('private checkpoint directory required', top))
        entries.append((top, root/top))
        for parent, dirs, files in os.walk(root/top, followlinks=False):
            dirs[:] = sorted(n for n in dirs if selected(str((Path(parent)/n).relative_to(root))))
            for n in dirs + sorted(files):
                p = Path(parent)/n; name = str(p.relative_to(root))
                if selected(name):
                    if p.is_symlink():
                        raw = os.readlink(p)
                        if os.path.isabs(raw):
                            if not Path(os.path.normpath(raw)).is_relative_to(root):
                                raise ValueError(('external checkpoint link', name))
                            try:
                                resolved = p.resolve(strict=True)
                            except (OSError, RuntimeError) as error:
                                raise ValueError(('invalid checkpoint link', name)) from error
                            if not resolved.is_relative_to(root):
                                raise ValueError(('external checkpoint link', name))
                            target = str(resolved.relative_to(root))
                            links[name] = os.path.relpath(resolved, p.parent)
                        else:
                            target = os.path.normpath(str(Path(name).parent/raw))
                            links[name] = raw
                        if target in ('.', '..') or target.startswith('../') or not selected(target):
                            raise ValueError(('external checkpoint link', name))
                        try:
                            os.stat(p)  # The kernel must accept the raw target spelling.
                        except OSError as error:
                            raise ValueError(('invalid checkpoint link', name)) from error
                    elif not (p.is_file() or p.is_dir()):
                        raise ValueError(('special checkpoint file', name))
                    entries.append((name, p))
    names = {name for name, p in entries}
    for name, link in links.items():
        target = os.path.normpath(str(Path(name).parent/link))
        if target not in names:
            raise ValueError(('missing checkpoint link target', name))
    def normalized_link(info):
        if info.issym():
            info.linkname = links[info.name]
        return info
    # All namespace checks precede checkpoint writes; tar preserves hardlinks.
    dest.mkdir(parents=True)
    with tarfile.open(dest/'tree.tar', 'w', format=tarfile.PAX_FORMAT) as archive:
        for name, p in entries:
            archive.add(p, arcname=name, recursive=False, filter=normalized_link)
    (dest/'layout.json').write_text(json.dumps({'root': str(root), 'members': [n for n,p in entries],
        'mtimeNs': {n: p.lstat().st_mtime_ns for n,p in entries}}, sort_keys=True)+'\n')



if __name__ == '__main__':
    if sys.argv[1]!='save': raise ValueError('unknown production checkpoint action')
    save(*map(Path,sys.argv[2:]))
