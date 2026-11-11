"""Small pre-write red/green controls, independent of any package compilation."""
import importlib.util
import os
from pathlib import Path
import shutil
import sys
import tempfile

spec = importlib.util.spec_from_file_location('guard', sys.argv[1])
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
with tempfile.TemporaryDirectory() as directory:
    top = Path(directory).resolve()
    def fixture(name):
        root = top/name
        (root/'bin').mkdir(parents=True)
        for n in ['xzdiff', 'xzgrep', 'xzmore', 'xzless']:
            (root/'bin'/n).write_bytes(b'#!/nix/store/selected/bin/bash\n' + (
                b'if test "$(less -V)"; then :; fi\nexec less "$@"\n' if n == 'xzless' else b'echo helper\n'))
        return root
    root = fixture('positive')
    guard.validate('output', str(root))
    count = 0
    for defect in ['nul', 'encoding', 'frontend', 'symlink', 'hardlink', 'fifo', 'late-text', 'parent', 'root']:
        root = fixture(defect)
        p = root/'bin/xzgrep'
        if defect == 'nul': p.write_bytes(p.read_bytes()+b'\0')
        if defect == 'encoding': p.write_bytes(p.read_bytes()+b'\xff')
        if defect == 'frontend': p.write_bytes(b'#!/usr/bin/env sh\necho no\n')
        if defect == 'symlink': p.unlink();p.symlink_to('xzmore')
        if defect == 'hardlink': os.link(p,root/'alias')
        if defect == 'fifo': os.mkfifo(root/'fifo')
        if defect == 'late-text': (root/'zz-text').write_bytes(b'bad\xff')
        if defect == 'parent':
            (root/'bin').rename(root/'real-bin');(root/'bin').symlink_to('real-bin')
        if defect == 'root':
            alias=top/'root-alias';alias.symlink_to(root);root=alias
        before={str(p):p.read_bytes() for p in root.rglob('*') if p.is_file()}
        try: guard.validate('output',str(root))
        except (ValueError, UnicodeError): count+=1
        else: raise AssertionError(defect)
        assert before=={str(p):p.read_bytes() for p in root.rglob('*') if p.is_file()},defect
    # Source validation covers entire text, including late bytes after frontend.
    root=top/'source';(root/'build-aux').mkdir(parents=True);(root/'src/scripts').mkdir(parents=True)
    (root/'configure').write_bytes(b'#!/bin/sh\necho source\n')
    (root/'build-aux/ltmain.sh').write_bytes(b'#!/bin/sh\necho ltmain\n')
    for n in ['xzdiff','xzgrep','xzmore','xzless']:
        (root/'src/scripts'/f'{n}.in').write_bytes(b'#!@POSIX_SHELL@\necho script\n')
    guard.validate('source',str(root))
    (root/'build-aux/ltmain.sh').write_bytes(b'#!/bin/sh\necho source\n\0')
    try: guard.validate('source',str(root))
    except ValueError: count+=1
    else: raise AssertionError('source NUL')
print('guards',count)
