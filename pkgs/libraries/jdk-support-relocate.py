"""Rebase the JDK support libraries' exact installed self prefixes.

These procedures give A and F equal-width store names: compiled path/length
pairs (Fontconfig config/cache paths, ALSA data/modules, X11 locale data and
CUPS defaults) retain their widths. This is byte relocation, never a rebuild.
Only the declared A output prefixes are replaced; dependency paths stay intact.
Evidence logs are copied/rebased separately, not interpreted as installed code.
"""
import os
from pathlib import Path
import sys


def relocate(roots, pairs):
    for old, new in pairs:
        if len(old) != len(new):
            raise ValueError('JDK support compiled paths require equal-width prefixes')
    for root in roots:
        for current, dirs, files in os.walk(root, followlinks=False):
            for name in dirs + files:
                path = Path(current, name)
                if path.is_symlink():
                    target = os.fsencode(os.readlink(path))
                    changed = target
                    for old, new in pairs:
                        changed = changed.replace(old, new)
                    if changed != target:
                        path.unlink()
                        path.symlink_to(os.fsdecode(changed))
                elif path.is_file():
                    data = path.read_bytes()
                    changed = data
                    for old, new in pairs:
                        changed = changed.replace(old, new)
                    if data != changed:
                        stat = path.stat()
                        # Keep hardlinks and file modes; compiled string sizes do
                        # not change. The copy step already made files writable.
                        with path.open('r+b') as stream:
                            stream.write(changed)
                        os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns))


if __name__ == '__main__':
    # Each named output has its own hash; never derive a sibling's store path.
    args = sys.argv[1:]
    if len(args) not in (2, 4):
        raise ValueError('expected out/artifact and optional evidence/artifact pair')
    roots = [Path(p) for p in args[::2]]
    pairs = [(os.fsencode(old), os.fsencode(new))
             for new, old in zip(args[::2], args[1::2])]
    relocate(roots, pairs)
