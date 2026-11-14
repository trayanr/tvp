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
replace('Makefile.pre.in', [('SHELL=\t\t/bin/sh', 'SHELL= ' + build_shell)])
config_replacements = [('#!/bin/sh', '#!' + build_shell),
    ('dirname ', utilities + '/dirname '), ('which readlink', 'command -v ' + utilities + '/readlink'),
    ('readlink -f', utilities + '/readlink -f')]
# Newer templates relocate with shell expansion and no longer invoke sed.
if '| sed ' in Path('Misc/python-config.sh.in').read_text():
    config_replacements.append(('| sed ', '| ' + sed + ' '))
replace('Misc/python-config.sh.in', config_replacements)
