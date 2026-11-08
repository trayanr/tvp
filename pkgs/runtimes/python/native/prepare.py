"""Bind declared shells/tools without causing release-source regeneration."""
from pathlib import Path
import os
import sys
runtime_shell, build_shell, utilities, sed = sys.argv[1:]

def replace(path, replacements):
    p = Path(path)
    st = p.stat()
    text = p.read_text()
    for old, new in replacements:
        assert old in text, (path, old)
        text = text.replace(old, new)
    p.write_text(text)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))

replace('Lib/subprocess.py', [('@TVP_SHELL@', runtime_shell)])
replace('Makefile.pre.in', [('SHELL=\t\t/bin/sh -e', 'SHELL= ' + build_shell + ' -e')])
replace('Misc/python-config.sh.in', [('#!/bin/sh', '#!' + build_shell),
    ('dirname ', utilities + '/dirname '), ('which readlink', 'command -v ' + utilities + '/readlink'),
    ('readlink -f', utilities + '/readlink -f'), ('| sed ', '| ' + sed + ' ')])
