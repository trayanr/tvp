"""Installed profile contracts. Empty environments test compiled data defaults."""
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import subprocess
import sys

libc, old, shell, out, evidence, readelf = sys.argv[1:]
evidence = Path(evidence)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
records = []


def run(argv, env=None, expected=0, input=None):
    p = subprocess.run(argv, input=input, env={} if env is None else env,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    records.append(dict(argv=list(map(str, argv)), env=env or {}, status=p.returncode,
                        stdout=p.stdout.decode(errors='backslashreplace'),
                        stderr=p.stderr.decode(errors='backslashreplace')))
    (evidence / 'execution.json').write_text(json.dumps(records, indent=2) + '\n')
    if expected is None:
        assert p.returncode != 0, records[-1]
    else:
        assert p.returncode == expected, records[-1]
    return p.stdout


loader = libc + '/lib/ld-linux-x86-64.so.2'
for mode in ['dynamic', 'static']:
    binary = out + '/bin/' + mode
    info = run([readelf, '-l', '-d', binary]).decode()
    (evidence / (mode + '.elf')).write_text(info)
    if mode == 'dynamic':
        assert 'Requesting program interpreter: ' + loader in info
        assert '[' + libc + '/lib]' in info
        assert '(NEEDED)' in info and '[libc.so.6]' in info
    else:
        assert 'INTERP' not in info and '(NEEDED)' not in info
    trace = (evidence / (mode + '-link.log')).read_text()
    assert libc + '/include' in trace and libc + '/lib/crt1.o' in trace
    assert libc + '/lib/crti.o' in trace and libc + '/lib/crtn.o' in trace
    assert libc + '/lib/libc.' in trace
    # Old compiler configuration can mention its old sysroot. It may never
    # select an old header/startup/library as an actual traced linker input.
    assert not re.search(r'^' + re.escape(old) + r'/lib/', trace, re.M)
    result = run([binary])
    assert b'PASS locale=7 conversions=4 rejection=4 shell=5' in result
    if mode == 'dynamic':
        assert ('libc=' + libc + '/lib/libc.so.6').encode() in result
        assert (libc + '/lib/gconv/ISO8859-1.so').encode() in result
        assert (libc + '/lib/gconv/UTF-16.so').encode() in result
        assert run([loader, binary]) == result
        listing = run([loader, '--list', binary]).decode()
        assert libc + '/lib/libc.so.6' in listing and old not in listing
        run([binary], env={'LOCPATH': '/foreign/locale'}, expected=None)
        run([binary], env={'GCONV_PATH': '/foreign/gconv'}, expected=None)
        run([binary], env={'SHELL': '/foreign/sh'})
# This exact guard would reject the host shell even if one is available.
run([shell, '-c', 'test /proc/$$/exe -ef "' + shell + '"'])
if Path('/bin/sh').exists():
    run(['/bin/sh', '-c', 'test /proc/$$/exe -ef "' + shell + '"'], expected=None)
for tool in ['bin/locale', 'bin/localedef', 'bin/iconv', 'sbin/iconvconfig']:
    path = libc + '/' + tool
    info = run([readelf, '-l', '-d', path]).decode()
    assert 'Requesting program interpreter: ' + loader in info
    assert libc + '/lib/libc.so.6' in run([loader, '--list', path]).decode()
    run([path, '--version'])
assert b'C.UTF-8' in run([libc + '/bin/locale', '-a'])
assert run([libc + '/bin/locale', 'charmap'], env={'LC_ALL': 'C.UTF-8'}).strip() == b'UTF-8'
assert b'ISO-8859-1' in run([libc + '/bin/iconv', '-l'])
assert run([libc + '/bin/iconv', '-f', 'UTF-8', '-t', 'ISO-8859-1'], input=b'A\xc3\xa9') == b'A\xe9'
run([libc + '/bin/iconv', '-f', 'UTF-8', '-t', 'UTF-16LE'], input=b'\xff', expected=None)
run([libc + '/bin/iconv', '-f', 'UTF-8', '-t', 'UTF-16LE'], input=b'\xc3', expected=None)
gconv = Path(libc) / 'lib/gconv'
files = {str(p.relative_to(gconv)): dict(bytes=p.stat().st_size,
         sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(gconv.rglob('*')) if p.is_file()}
assert 'gconv-modules.cache' in files and 'gconv-modules' in files
(evidence / 'gconv-inventory.json').write_text(json.dumps(dict(files=files,
    retainedModules=sum(n.endswith('.so') for n in files), minimalSetClaim=False), indent=2) + '\n')
(evidence / 'summary.json').write_text(json.dumps(dict(status='PASS', invocations=len(records),
    dynamicAndStatic=True, compiledDataDefaults=True, newLoader=loader,
    priorStageShell=shell, fullConformance=False), indent=2) + '\n')
