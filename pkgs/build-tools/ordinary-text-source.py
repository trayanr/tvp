"""Confined Autotools and shell-fixture preparation for ordinary text tools.

The caller supplies the complete shell fixture selection. Validate the entire tree
and all frontends, anchors and temporary names before preparing any replacement.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

shell, perl, selections = sys.argv[1:]
selections = json.loads(selections)
root = Path.cwd().resolve(strict=True)
files = []
aliases = []
for directory, dirs, names in os.walk(root, followlinks=False):
    for name in sorted(dirs + names):
        path = Path(directory) / name
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            if os.path.isabs(os.readlink(path)) or not path.resolve(strict=True).is_relative_to(root) or path.is_dir():
                raise ValueError(('unsafe source alias', path))
            aliases.append(path)
        elif stat.S_ISREG(info.st_mode):
            if info.st_nlink != 1:
                raise ValueError(('source hardlink', path))
            files.append(path)
        elif not stat.S_ISDIR(info.st_mode):
            raise ValueError(('special source file', path))
for selection in selections:
    path = root / selection
    if path not in files and (not path.is_dir() or path.is_symlink()):
        raise ValueError(('missing independent fixture selection', path))
def selected(path):
    return any(path == root / s or path.is_relative_to(root / s) for s in selections)

# Do not follow selected leaf aliases into files outside the lexical selection.
# Callers can select the independent regular file explicitly instead.
for path in aliases:
    if selected(path):
        raise ValueError(('selected fixture alias', path))

# These are interpreter input data, not command frontends. Gawk's Makefile
# invokes AWK -f explicitly; poundbang.awk is input to its generated-interpreter
# test. Sed likewise reads dc.sed with its built interpreter. Keep their original
# first lines because the tests exercise them. Exact paths AND first lines are
# required: a suffix alone never grants an interpreter exception.
data_frontends = {
    'testsuite/dc.sed': b'#!/bin/sed -nf',
    'test/poundbang.awk': b'#! /tmp/gawk -f ',
    'test/Gentests': b'#!/usr/bin/gawk -f',
    'test/arrayind1.awk': b'#!/usr/local/bin/awk -f',
    'test/aryprm9.awk': b'#!/usr/bin/gawk -f',
    'test/clsflnam.awk': b'#! /usr/bin/awk -f',
    'test/elemnew2.awk': b'#!/usr/bin/gawk -f',
    'test/fcall_exit.awk': b'#!/bin/awk -f',
    'test/fcall_exit2.awk': b'#!/bin/awk -f',
    'test/fnarydel.awk': b'#!/usr/local/bin/gawk -f',
    'test/fpat9.awk': b'#! /bin/gawk  -f',
    'test/mdim8.awk': b'#!/bin/awk -f',
    'test/mpfrfield.awk': b'#! /bin/gawk -Mf',
    'test/watchpoint1.awk': b'#! /usr/bin/gawk -f',
}
configure = root / 'configure'
if configure not in files or not re.match(rb'#![ \t]*/bin/sh\n', configure.read_bytes()):
    raise ValueError('expected original configure /bin/sh frontend')
changes = {configure: b'#!' + shell.encode() + b'\n' + configure.read_bytes().split(b'\n', 1)[1].replace(b'/usr/bin/file', b'file')}
anchors = {}
for path in files:
    data = path.read_bytes()
    if path.name == 'ltmain.sh':
        search = b' '.join(f[2:].encode() for f in os.environ.get('NIX_LDFLAGS', '').split() if f.startswith('-L'))
        data, count = re.subn(rb'eval (sys_lib_search_path=).*', lambda m: m[1] + b"'" + search + b"'", data)
        if count != 1:
            raise ValueError(('ltmain search anchor', path, count))
        anchors[str(path.relative_to(root))] = count
        changes[path] = re.sub(rb'eval sys_lib_.+search_path=.*', b'', data)
    if selected(path) and data.startswith(b'#!'):
        front, body = data.split(b'\n', 1)
        if re.fullmatch(rb'#![ \t]*(?:/bin/(?:sh|bash)|/usr/bin/env (?:sh|bash))(?: (-e|-))?', front):
            changes[path] = b'#!' + shell.encode() + (b' ' + front.split()[-1] if front.split()[-1] in {b'-e', b'-'} else b'') + b'\n' + body
        elif re.fullmatch(rb'#![ \t]*(?:/usr/bin/perl|/usr/bin/env perl)(?: -w)?', front):
            changes[path] = b'#!' + perl.encode() + (b' -w' if front.endswith(b' -w') else b'') + b'\n' + body
        elif data_frontends.get(str(path.relative_to(root))) != front:
            raise ValueError(('unexpected fixture frontend', path, front))
for path in changes:
    if os.path.lexists(str(path) + '.tvp-prepare'):
        raise ValueError(('preparation collision', path))
for path, data in changes.items():
    info = path.stat()
    temp = Path(str(path) + '.tvp-prepare')
    with temp.open('xb') as stream:
        stream.write(data)
    os.chmod(temp, stat.S_IMODE(info.st_mode))
    os.utime(temp, ns=(info.st_atime_ns, info.st_mtime_ns))
for path in changes:
    os.replace(str(path) + '.tvp-prepare', path)
print(json.dumps({'validatedFiles': len(files), 'anchors': anchors, 'adaptations': {
    str(path.relative_to(root)): hashlib.sha256(data).hexdigest() for path, data in changes.items()
}}, sort_keys=True))
