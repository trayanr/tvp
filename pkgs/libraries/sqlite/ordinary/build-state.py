"""Bounded upstream checkpoint, never a workspace snapshot. No configure/build dispatch."""
import fnmatch
import json
import os
from pathlib import Path
import stat
import sys
import tarfile


def namespace(root):
    if not root.is_absolute() or root.is_symlink() or root.resolve() != root:
        raise ValueError('noncanonical private tree')
    for parent, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            p = Path(parent) / name
            s = p.lstat()
            if stat.S_ISLNK(s.st_mode):
                if not p.resolve(strict=True).is_relative_to(root):
                    raise ValueError(f'external link: {p}')
            elif not (stat.S_ISREG(s.st_mode) or stat.S_ISDIR(s.st_mode)):
                raise ValueError(f'special file: {p}')
            elif stat.S_ISREG(s.st_mode) and s.st_nlink != 1:
                raise ValueError(f'aliased file: {p}')


def save(root, dest, manifest, protocol, prefix, epoch, fixture=False):
    namespace(root)
    spec = json.loads(manifest.read_text())['protocols'][protocol]
    for name in spec['required']:
        if not (root / name).exists():
            raise ValueError(f'missing checkpoint member: {name}')
    dest.mkdir(parents=True, exist_ok=False)
    def allowed(path):
        rel = path.relative_to(root)
        if any(x in ('.git', '.hg', '.svn') for x in rel.parts) or (len(rel.parts) == 1 and
                (rel.name in spec['excluded'] or rel.name.endswith(('.db', '.db-journal', '.db-wal', '.db-shm', '.log')))):
            return fixture and rel.as_posix() in ('testfixture', 'testfixture.exe')
        top = rel.parts[0]
        return (top in spec['sourceTopLevels'] or top in spec['generatedDirectories']
                or (len(rel.parts) == 1 and any(fnmatch.fnmatch(top, p) for p in spec['generatedPatterns'])))
    members = []
    metadata = {}
    # tar preserves modes, ns-rounded mtimes, relative symlinks and source layout.
    # Private extraction checks every link before writes and never follows links.
    with tarfile.open(dest / 'tree.tar', 'w', format=tarfile.PAX_FORMAT) as archive:
        for parent, dirs, files in os.walk(root, followlinks=False):
            dirs[:] = sorted(d for d in dirs if allowed(Path(parent) / d))
            for name in dirs + sorted(files):
                p = Path(parent) / name
                if allowed(p):
                    rel = p.relative_to(root).as_posix()
                    archive.add(p, arcname=rel, recursive=False)
                    members.append(rel)
                    info = p.lstat()
                    metadata[rel] = {'mtimeNs': info.st_mtime_ns, 'mode': stat.S_IMODE(info.st_mode)}
    (dest / 'layout.json').write_text(json.dumps({
        'schema': 1, 'protocol': protocol, 'source': str(root), 'prefix': prefix,
        'sourceDateEpoch': epoch.read_text().strip(), 'fixture': fixture,
        'members': members, 'metadata': metadata,
    }, sort_keys=True) + '\n')


if __name__ == '__main__':
    if sys.argv[1] != 'save':
        raise ValueError('unknown checkpoint operation')
    save(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4]), sys.argv[5],
         sys.argv[6], Path(sys.argv[7]), len(sys.argv) == 9 and sys.argv[8] == 'fixture')
