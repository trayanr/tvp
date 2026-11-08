"""Require the complete measured ordinary payload and exercise native interfaces."""
import ctypes
import curses
import decimal
import importlib
import json
import locale
import os
from pathlib import Path
import readline
import sqlite3
import subprocess
import sys
import sysconfig
import threading
import time
baseline = json.loads(Path(sys.argv[1]).read_text())
root, shell = Path(sys.argv[2]), sys.argv[3]
config = sysconfig.get_config_vars()
for key, state in baseline['moduleStates'].items():
    if state == 'yes':
        assert config[key] == state, (key, state, config.get(key))
actual = sorted(p.name.split('.')[0] for p in (root/'lib/python3.15/lib-dynload').glob('*.so'))
assert actual == baseline['dynamicModules'], (set(actual)^set(baseline['dynamicModules']))
for name in actual:
    importlib.import_module(name)
assert config['PY_ENABLE_SHARED'] == 0
assert config['PY_SQLITE_ENABLE_LOAD_EXTENSION'] == 0
assert config['PY_SQLITE_HAVE_SERIALIZE'] == 1
assert (root/'lib/libpython3.15.a').is_file()
assert not list((root/'lib').glob('libpython*.so*'))
assert (root/'include/python3.15/Python.h').is_file()
assert (root/'lib/python3.15/test/test_ssl.py').is_file()
assert (root/'lib/python3.15/ensurepip/_bundled').is_dir()
assert not (root/'config.log').exists()
with sqlite3.connect(':memory:') as db:
    db.execute('create table t (n)');db.execute('insert into t values (42)')
    saved = db.serialize()
    with sqlite3.connect(':memory:') as other:
        other.deserialize(saved); assert other.execute('select n from t').fetchone() == (42,)
    assert not hasattr(db, 'enable_load_extension')
callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int)(lambda n: n+1)
assert callback(41)==42
with decimal.localcontext() as ctx:
    ctx.prec = 50
    assert decimal.Decimal(2).sqrt() ** 2 > decimal.Decimal('1.999999999999999999999999999999999999999999999999')
readline.clear_history();readline.add_history('tvp');assert readline.get_history_item(1)=='tvp'
# Terminfo comes from the selected ncurses provider; no terminal emulation needed.
curses.setupterm(term='xterm'); assert curses.tigetnum('colors') >= 8
assert subprocess.check_output('printf "%s" "$BASH"', shell=True, text=True) == shell
values=[]; t=threading.Thread(target=lambda: values.append(42));t.start();t.join();assert values==[42]
for loc in ('C', 'C.UTF-8'):
    locale.setlocale(locale.LC_CTYPE, loc)
    for encoding, word in [('utf-8','Здравей'),('shift_jis','日本'),('gb18030','中国')]:
        assert word.encode(encoding).decode(encoding)==word
    name=Path('тест');name.write_text('42');assert name.read_text()=='42';name.unlink()
assert time.gmtime(0).tm_year==1970
for name in ('pip3','pip3.15','pydoc3.15','idle3.15'):
    assert (root/'bin'/name).read_bytes().splitlines()[0] == b'#!'+str(root).encode()+b'/bin/python3'
print('complete')
