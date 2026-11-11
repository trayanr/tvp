"""Small pre-write red/green controls, independent of any package compilation."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile

spec = importlib.util.spec_from_file_location('guard', sys.argv[1])
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
spec = importlib.util.spec_from_file_location('output_guard', sys.argv[2])
output_guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(output_guard)


def validate(mode, name):
    if mode == 'output':
        return output_guard.validate(name, guard.validate, guard.text)
    return guard.validate(mode, name)


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
    (root/'lib').mkdir()
    (root/'lib/liblzma.a').write_bytes(b'!<arch>\n\0\xff')
    (root/'share/locale').mkdir(parents=True)
    (root/'share/locale/messages.mo').write_bytes(b'\xde\x12\x04\x95\0\xff')
    validate('output', str(root))
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
        try: validate('output',str(root))
        except (ValueError, UnicodeError): count+=1
        else: raise AssertionError(defect)
        assert before=={str(p):p.read_bytes() for p in root.rglob('*') if p.is_file()},defect
    # Known metadata must not select binary routing by containing the byte the
    # text contract rejects. Include nested headers and aliases to other names.
    targets = ['lib/pkgconfig/liblzma.pc', 'lib/liblzma.la', 'include/lzma.h',
               'include/lzma/base.h', 'share/aclocal/liblzma.m4',
               'share/man/man1/xz.1', 'share/doc/xz/README',
               'nix-support/source-date-epoch']
    for index, relative in enumerate(targets):
        for defect, tail in [('NUL', b'\0'), ('NUL-encoding', b'\0\xff'), ('encoding', b'\xff')]:
            root = fixture(f'text-{index}-{defect}')
            p = root/relative
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(b'prefix=/nix/store/selected-artifact\n'+tail)
            before = p.read_bytes()
            try: validate('output', str(root))
            except (ValueError, UnicodeError): count += 1
            else: raise AssertionError((relative, defect))
            assert p.read_bytes() == before
    for index, relative in enumerate(targets[:2]):
        for defect, tail in [('NUL', b'\0'), ('NUL-encoding', b'\0\xff')]:
            root = fixture(f'alias-{index}-{defect}')
            target = root/'metadata.bin'
            target.write_bytes(b'prefix=/nix/store/selected-artifact\n'+tail)
            p = root/relative
            p.parent.mkdir(parents=True, exist_ok=True)
            p.symlink_to(os.path.relpath(target, p.parent))
            before = target.read_bytes()
            try: validate('output', str(root))
            except (ValueError, UnicodeError): count += 1
            else: raise AssertionError((relative, defect))
            assert target.read_bytes() == before
    # Source validation covers entire text, including late bytes after frontend.
    root=top/'source';(root/'build-aux').mkdir(parents=True);(root/'src/scripts').mkdir(parents=True)
    (root/'configure').write_bytes(b'#!/bin/sh\necho source\n')
    (root/'build-aux/ltmain.sh').write_bytes(b'#!/bin/sh\necho ltmain\n')
    for n in ['xzdiff','xzgrep','xzmore','xzless']:
        (root/'src/scripts'/f'{n}.in').write_bytes(b'#!@POSIX_SHELL@\necho script\n')
    validate('source',str(root))
    (root/'build-aux/ltmain.sh').write_bytes(b'#!/bin/sh\necho source\n\0')
    try: validate('source',str(root))
    except ValueError: count+=1
    else: raise AssertionError('source NUL')
print('guards',count)
