"""Rebase installed Tcl prefixes, including compiled Tcl library path constants.

Tcl's prefix and adjacent length/offset constants require equal-width names.
Zipfs script images remain disabled in the declared Tcl 9 profiles. No build
state is installed or relocated. Preserve installed file modes and timestamps.
"""
import os
from pathlib import Path
import sys


def relocate(root, old):
    new = os.fsencode(root)
    if len(old) != len(new):
        raise ValueError('Tcl compiled prefixes require equal-width store names')
    for directory in ('bin', 'lib', 'include', 'share', 'man', 'nix-support'):
        top = root / directory
        if not top.exists():
            continue
        for current, dirs, files in os.walk(top, followlinks=False):
            for name in dirs + files:
                path = Path(current, name)
                if path.is_symlink():
                    target = os.readlink(path)
                    if os.fsdecode(old) in target:
                        path.unlink()
                        path.symlink_to(target.replace(os.fsdecode(old), os.fsdecode(new)))
                elif path.is_file():
                    data = path.read_bytes()
                    if old in data:
                        stat = path.stat()
                        path.write_bytes(data.replace(old, new))
                        os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns))


if __name__ == '__main__':
    relocate(Path(sys.argv[1]), os.fsencode(os.environ['TVP_ARTIFACT_ROOT']))
