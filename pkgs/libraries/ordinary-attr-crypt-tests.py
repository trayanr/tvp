"""Adversarial all-before-write source/output contracts for these two libraries."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

source_helper, output_helper, shell, perl, readelf, patchelf = sys.argv[1:]
base = Path.cwd()

def digest(root):
    rows = []
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in sorted(dirs + files):
            p = Path(directory) / name
            st = p.lstat()
            value = os.readlink(p) if p.is_symlink() else hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else str(st.st_mode)
            rows.append((str(p.relative_to(root)), value, st.st_mode, st.st_ino, st.st_nlink))
    return rows

cases = ['source-alias', 'source-directory', 'source-hardlink', 'source-fifo',
         'source-collision', 'source-unknown', 'source-renamed-unknown', 'source-anchor',
         'output-alias', 'output-directory', 'output-hardlink', 'output-fifo',
         'output-collision', 'output-unknown', 'output-renamed-unknown',
         'output-manual-collision', 'output-malformed-elf', 'output-directory-as-file', 'output-nul-frontend']
for case in cases:
    root = base / case
    root.mkdir()
    external = base / (case + '-external')
    external.write_text('unchanged')
    if case.startswith('source'):
        (root/'configure').write_text('#!/bin/sh\n/usr/bin/file\n')
        (root/'build-aux').mkdir()
        (root/'test').mkdir()
        (root/'build-aux/ltmain.sh').write_text("#!/bin/sh\neval sys_lib_search_path=foo\n")
        target = root/'test/helper'
        target.write_text('#!/bin/sh\necho original\n')
        if case == 'source-alias': target.unlink(); target.symlink_to(external)
        if case == 'source-directory': (root/'test').rename(root/'fixtures'); (root/'test').symlink_to('fixtures')
        if case == 'source-hardlink': target.unlink(); os.link(external, target)
        if case == 'source-fifo': target.unlink(); os.mkfifo(target)
        if case == 'source-collision': (root/'configure.tvp-prepare').symlink_to(external)
        if case in ('source-unknown','source-renamed-unknown'): target.write_text('#!/usr/bin/python3\npass\n')
        if case == 'source-renamed-unknown': target.rename(root/'test/unexpected.dat')
        if case == 'source-anchor': (root/'build-aux/ltmain.sh').write_text('#!/bin/sh\nmissing anchor\n')
        args=[sys.executable,'-B',source_helper,shell,perl,'["build-aux","test"]']
    else:
        (root/'bin').mkdir(); (root/'lib').mkdir(); (root/'share/man/man1').mkdir(parents=True)
        target=root/'bin/helper'; target.write_text('#!/bin/sh\necho original\n'); target.chmod(0o755)
        if case == 'output-alias': (root/'lib/libcrypt.a').symlink_to('../bin/helper')
        if case == 'output-directory': (root/'bin').rename(root/'commands'); (root/'bin').symlink_to('commands')
        if case == 'output-hardlink': os.link(external,root/'lib/escape')
        if case == 'output-fifo': os.mkfifo(root/'lib/pipe')
        if case == 'output-collision': (root/'bin/helper.tvp-relocating').symlink_to(external)
        if case in ('output-unknown','output-renamed-unknown'): target.write_text('#!/usr/bin/python3\npass\n')
        if case == 'output-renamed-unknown': target.rename(root/'bin/unexpected.dat')
        if case == 'output-manual-collision': (root/'share/man/man1/a.1').write_text('one'); (root/'share/man/man1/a.1.gz').write_text('two')
        if case == 'output-directory-as-file': target.unlink(); (root/'bin').rmdir(); (root/'bin').symlink_to('../'+external.name)
        if case == 'output-nul-frontend': target.write_bytes(b'#!/usr/bin/python3\n\0pass\n')
        if case == 'output-malformed-elf': target.write_bytes(b'\x7fELF'+b'\0'*60)
        config={'readelf':readelf,'shell':shell,'buildShell':'/bin/sh','paths':[], 'requiredDirectories':['bin','lib','share/man'],'requiredFiles':[], 'requiredRegular':['lib/libcrypt.a'],'libtoolData':[]}
        args=[sys.executable,'-B',output_helper,str(root),'/nix/store/'+'x'*32+'-a-long-artifact-output',patchelf,json.dumps(config)]
    before=digest(root); outside=external.read_bytes()
    p=subprocess.run(args,cwd=root,capture_output=True)
    assert p.returncode and before==digest(root) and external.read_bytes()==outside, (case,p.stdout,p.stderr)
    print('PASS',case, file=sys.stderr)
print('ok')
