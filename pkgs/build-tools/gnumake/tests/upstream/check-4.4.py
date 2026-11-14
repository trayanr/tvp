"""Qualify Make 4.4's measured glibc default-PATH nonpass with fresh controls.

No upstream assertion is edited or skipped. Unknown failures remain fatal.
"""
from pathlib import Path
import json
import subprocess
import sys
status = int(sys.argv[1])
failures = sorted(Path('tests/work').rglob('*.diff*'))
log = Path('upstream.log').read_text()
for p in failures:
    print('RAW FAILURE', p, '\n' + p.read_text(), flush=True)
if status == 0:
    assert not failures
    result = 'PASS'
else:
    assert status == 2
    assert failures == [Path('tests/work/misc/general4.diff.9')], failures
    assert Path('tests/work/misc/general4.base.9').read_text() == 'hi\n'
    assert Path('tests/work/misc/general4.log.9').read_text() == (
        'make: echo: No such file or directory\n'
        'make: *** [work/misc/general4.mk.9:2: a] Error 127\n')
    assert '1 Test in 1 Category Failed' in log
    # Reproduce the exact recipe independently, then supply only declared echo.
    fixture=Path('default-path-control.mk')
    fixture.write_text('a: ; @echo hi\n')
    make=str(Path('make').resolve(strict=True))
    absent=subprocess.run([make,'--no-print-directory','-f',str(fixture)],env={},text=True,capture_output=True)
    present=subprocess.run([make,'--no-print-directory','-f',str(fixture)],env={'PATH':sys.argv[2]},text=True,capture_output=True)
    assert absent.returncode==2 and absent.stdout==''
    assert absent.stderr == ('make: echo: No such file or directory\nmake: *** [default-path-control.mk:1: a] Error 127\n'), absent
    assert present.returncode==0 and present.stdout=='hi\n' and present.stderr==''
    print(json.dumps({'controlAbsent':vars(absent),'controlDeclaredPath':vars(present)},sort_keys=True),flush=True)
    result='BOUNDED_NONPASS_LIBC_DEFAULT_PATH'
print(json.dumps({'rawStatus':status,'classification':result,'failureDiffs':[str(p) for p in failures],
'limits':'Guile/VMS retain upstream exclusions. A bounded nonpass is not strict conformance.'},sort_keys=True),flush=True)
