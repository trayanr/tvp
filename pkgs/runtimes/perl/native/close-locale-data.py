"""Backport Perl 5.32's locale-test DATA handle close to the 5.30 test tree."""
import hashlib
import json
import os
from pathlib import Path
import stat
import sys


def prepare(name):
    root = Path(name)
    if not root.is_absolute() or root.resolve(strict=True) != root:
        raise ValueError('canonical absolute Perl test root required')
    for parent in [root / 't', root, *root.parents]:
        if not stat.S_ISDIR(parent.lstat().st_mode):
            raise ValueError('regular Perl test directories required')
    target = root / 't/loc_tools.pl'
    info = target.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise ValueError('unlinked regular locale test helper required')
    before = target.read_bytes()
    before.decode('utf-8', errors='strict')
    anchor = b'        # The rest of the locales are in this file.\n        push @Data, <DATA>;\n'
    if b'\0' in before or before.count(anchor) != 1:
        raise ValueError('Perl 5.30 locale DATA anchor mismatch')
    after = before.replace(anchor, anchor[:-1] + b' close DATA;\n', 1)
    with target.open('r+b') as output:
        output.write(after)
        output.truncate()
    os.utime(target, ns=(info.st_atime_ns, info.st_mtime_ns))
    return {'target': 't/loc_tools.pl',
            'before': hashlib.sha256(before).hexdigest(),
            'after': hashlib.sha256(after).hexdigest()}


if __name__ == '__main__':
    print(json.dumps(prepare(sys.argv[1]), sort_keys=True))
