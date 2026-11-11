"""Pure installed-tree, text and path inspection for output finalizers.

Family finalizers choose semantic roles and plan mutations. These primitives
never invoke a package recipe or modify files. Retained Perl compatibility keeps
its original byte-bound helper until that caller's identities may change.
"""
import os
from pathlib import Path
import stat


def text(data, name):
    if b'\0' in data:
        raise ValueError(('NUL in installed text', name))
    data.decode('utf-8', errors='strict')
    return data


def replace_paths(data, old, new):
    # The prefix is a complete store basename, never a substring of another
    # pathname. Quotes, separators and whitespace delimit standalone prefixes.
    allowed = b"/\x00\n\r\t '\";:),]}<>"
    start = 0
    while True:
        pos = data.find(old, start)
        if pos < 0:
            break
        end = pos + len(old)
        if (pos and (chr(data[pos-1]).isalnum() or data[pos-1] in b'/_+-.')) or (end < len(data) and data[end] not in allowed):
            raise ValueError(('non-path prefix occurrence', pos))
        start = end
    return data.replace(old, new)


def tree(root):
    root = Path(root)
    if not root.is_absolute() or str(root) != str(root.resolve(strict=True)):
        raise ValueError('canonical absolute installed root required')
    for p in [root, *root.parents]:
        if not stat.S_ISDIR(p.lstat().st_mode):
            raise ValueError(('symlink/non-directory parent', p))
    files, links, groups = {}, {}, {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        for n in sorted(dirs + names):
            p = Path(directory)/n
            st = p.lstat(); name = str(p.relative_to(root))
            if stat.S_ISREG(st.st_mode):
                files[name] = p
                groups.setdefault((st.st_dev, st.st_ino), []).append(name)
            elif stat.S_ISLNK(st.st_mode):
                links[name] = os.readlink(p)
            elif not stat.S_ISDIR(st.st_mode):
                raise ValueError(('special installed node', name))
    for group in groups.values():
        if files[group[0]].stat().st_nlink != len(group):
            raise ValueError(('outside hardlink alias', group))
    return root, files, list(groups.values()), links


def audit(root, artifacts):
    root, files, groups, links = tree(root)
    for name, p in files.items():
        data = p.read_bytes()
        for artifact in artifacts:
            if artifact.encode() in data:
                raise ValueError(('artifact bytes remain', name, artifact))
    for name, target in links.items():
        if any(a in target for a in artifacts):
            raise ValueError(('artifact symlink remains', name))
        candidate = Path(target) if target.startswith('/') else (root/name).parent/target
        if not candidate.resolve(strict=True).is_relative_to(root):
            raise ValueError(('dangling/escaping final symlink', name))
