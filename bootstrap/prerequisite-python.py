"""Bounded build-interpreter contracts, run by the owned interpreter in env -i."""
import argparse
import collections
import functools
import importlib.util
import itertools
import json
import operator
import os
from pathlib import Path
import re
import string
import struct
import subprocess
import sys
import tempfile

assert sys.version_info[:3] == (3, 12, 5), sys.version
shell = sys.argv[1]
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'fixture space'
    path.write_text('42\n')
    assert path.read_text() == '42\n'
    result = subprocess.run('printf "%s" "$BASH_VERSION"', shell=True,
                            check=True, capture_output=True, text=True, env={})
    assert result.stdout.startswith('5.3.'), result
    assert subprocess.check_output([shell, '-c', 'printf owned'], env={}) == b'owned'
    assert subprocess.check_output('printf 42', shell=True, env={}) == b'42'
assert re.fullmatch(r'\d+', '42') and struct.calcsize('Q') == 8
assert collections.Counter('aba')['a'] == 2
for name in ('_bz2', '_crypt', '_ctypes', '_curses', '_curses_panel', '_dbm',
             '_gdbm', '_hashlib', '_lzma', '_sqlite3', '_ssl', '_tkinter',
             '_uuid', 'nis', 'readline', 'zlib', '_testcapi'):
    assert importlib.util.find_spec(name) is None, name
assert importlib.util.find_spec('pip') is None
print(json.dumps({'version': sys.version, 'shell': shell,
                  'fixture': 'temporary files and shell subprocess passed',
                  'os.system': 'unsupported: libc hardcodes /bin/sh; selected glibc scripts do not call it'}))
