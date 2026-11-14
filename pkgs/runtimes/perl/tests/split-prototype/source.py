"""Candidate source preparation only; no configure, compilation or finalization.

Callers select an explicit contract, including original patch files. This module
does not choose a recipe from a Perl version. Nothing imports it in production.
Validate the complete tree, text and edits before the first write. Upstream
internal hardlinks are allowed only when the entire inode group is contained.
"""
import hashlib
import os
from pathlib import Path
import re
import stat


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inventory(name):
    root = Path(name)
    if not root.is_absolute() or str(root) != name or root.resolve(strict=True) != root:
        raise ValueError('canonical absolute source root required')
    for parent in [root, *root.parents]:
        if not stat.S_ISDIR(parent.lstat().st_mode):
            raise ValueError(('symlink/non-directory parent', parent))
    files, groups, links = {}, {}, {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        for name in sorted(dirs + names):
            p = Path(directory) / name
            st = p.lstat()
            relative = str(p.relative_to(root))
            if stat.S_ISREG(st.st_mode):
                files[relative] = p
                groups.setdefault((st.st_dev, st.st_ino), []).append(relative)
            elif stat.S_ISLNK(st.st_mode):
                target = os.readlink(p)
                if os.path.isabs(target) or not p.resolve(strict=True).is_relative_to(root) or p.is_dir():
                    raise ValueError(('escaping/directory source alias', relative))
                links[relative] = target
            elif not stat.S_ISDIR(st.st_mode):
                raise ValueError(('special source node', relative))
    for group in groups.values():
        if files[group[0]].stat().st_nlink != len(group):
            raise ValueError(('outside hardlink alias', group))
    return root, files, list(groups.values()), links


def text(data, name):
    if b'\0' in data:
        raise ValueError(('NUL in declared text', name))
    data.decode('utf-8', errors='strict')
    return data


def exact_patch(data, patch, target):
    """Apply every original unified hunk with exact full context, no fuzz.

    Line numbers are advisory across adjacent upstream releases. Every full
    preimage must occur once, in order; all original patch bytes are receipted.
    Only the explicitly named single-file patch format is accepted.
    """
    lines = text(patch, 'patch').splitlines(keepends=True)
    if lines[:2] != [f'--- a/{target}\n'.encode(), f'+++ b/{target}\n'.encode()]:
        raise ValueError('unexpected patch target/format')
    hunks, current = [], None
    for line in lines[2:]:
        if line.startswith(b'@@ '):
            if not re.fullmatch(rb'@@ -[0-9]+,[0-9]+ \+[0-9]+,[0-9]+ @@\n', line):
                raise ValueError('unsupported hunk header')
            current = [[], []]
            hunks.append(current)
        elif current is None or line[:1] not in (b' ', b'+', b'-'):
            raise ValueError('unsupported hunk payload')
        else:
            if line[:1] in (b' ', b'-'):
                current[0].append(line[1:])
            if line[:1] in (b' ', b'+'):
                current[1].append(line[1:])
    positions, last = [], -1
    for old, new in hunks:
        old, new = b''.join(old), b''.join(new)
        if not old or data.count(old) != 1 or data.index(old) <= last:
            raise ValueError(('patch context mismatch/order', target))
        last = data.index(old)
        positions.append({'offset': last, 'before': digest(old), 'after': digest(new)})
        data = data.replace(old, new, 1)
    if not positions:
        raise ValueError('empty patch')
    return data, positions


def prepare(name, contract):
    root, files, groups, links = inventory(name)
    shell, diff, pwd = (contract[k] for k in ('shell', 'diff', 'buildPwd'))
    for tool in (shell, diff, pwd):
        if not tool.startswith('/nix/store/') or not Path(tool).is_file() or not os.access(tool, os.X_OK):
            raise ValueError(('missing explicit source tool', tool))
    required = ['Configure', 'perl.c', 'config_h.SH', 'configpm', 'installperl',
                'hints/linux.sh', 'dist/PathTools/Cwd.pm', 'ext/Errno/Errno_pm.PL', contract['podHelper']]
    for n in required:
        if n not in files:
            raise ValueError(('missing regular source target', n))
    selected = set(required)
    original = {n: text(files[n].read_bytes(), n) for n in sorted(selected)}
    changes, patches = dict(original), []
    for p in contract['patches']:
        patch = Path(p['file']).read_bytes()
        changes[p['target']], hunks = exact_patch(changes[p['target']], patch, p['target'])
        patches.append({'file': p['file'], 'sha256': digest(patch), 'hunks': hunks})
    for n in selected:
        data = changes[n]
        if n in ('Configure', 'hints/linux.sh'):
            if data.startswith(b'#!'):
                front, body = data.split(b'\n', 1)
                # Do not translate other interpreters, env options, or arguments.
                if not re.fullmatch(rb'#![ \t]*/bin/sh', front):
                    raise ValueError(('unsupported selected shell frontend', n, front))
                changes[n] = b'#!' + shell.encode() + b'\n' + body
            elif n == 'Configure':
                raise ValueError('missing Configure frontend')
    n = contract['podHelper']
    old = b"my $diff = '/bin/diff';"
    if changes[n].count(old) != 1:
        raise ValueError('Pod-Html diff anchor mismatch')
    changes[n] = changes[n].replace(old, b"my $diff = '" + diff.encode() + b"';")
    if contract['externalPwd']:
        n = 'dist/PathTools/Cwd.pm'
        if changes[n].count(b'/bin/pwd') != 5 or b"$pwd_cmd = 'pwd';" not in changes[n]:
            raise ValueError('old Cwd pwd contract mismatch')
        changes[n] = changes[n].replace(b'/bin/pwd', pwd.encode())
    configure = changes['Configure']
    if configure.count(b'Cannot build with both -Duserelocatableinc and -Duseshrplib') != 1:
        raise ValueError('missing shared/relocatable Configure conflict')
    if b'#ifndef PERL_RELOCATABLE_INCPUSH' not in original['perl.c']:
        raise ValueError('missing binary-relocation strlen hook')
    changes = {n: data for n, data in changes.items() if data != original[n]}
    # A changed inode group must receive one coherent value for all aliases.
    for group in groups:
        values = {changes[n] for n in group if n in changes}
        if values:
            if len(values) != 1:
                raise ValueError(('conflicting hardlink changes', group))
            for n in group:
                changes[n] = next(iter(values))
                original.setdefault(n, text(files[n].read_bytes(), n))
    receipt = {'contract': contract, 'validatedFiles': len(files), 'symlinks': links,
               'internalHardlinkGroups': [g for g in groups if len(g) > 1],
               'patches': patches, 'changes': {}}
    # All validation precedes writing; preserve internal hardlink topology.
    for group in groups:
        n = group[0]
        if n not in changes:
            continue
        p, data = files[n], changes[n]
        st = p.stat()
        with p.open('r+b') as f:
            f.write(data)
            f.truncate()
        os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
        for alias in group:
            receipt['changes'][alias] = {'before': digest(original[alias]), 'after': digest(data),
                                         'size': len(data), 'mode': stat.S_IMODE(st.st_mode)}
    return receipt
