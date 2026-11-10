"""Qualify Make 4.3's sandbox include-directory nonpass; unknowns fail."""
from pathlib import Path
import json
import subprocess
import sys
status=int(sys.argv[1]); failures=sorted(Path('tests/work').rglob('*.diff*'))
for p in failures: print('RAW FAILURE',p,'\n'+p.read_text(),flush=True)
if status == 0:
    assert not failures
    result='PASS'
else:
    assert status==2
    assert failures==[Path('tests/work/variables/INCLUDE_DIRS.diff')],failures
    assert Path('tests/work/variables/INCLUDE_DIRS.base').read_text()==''
    assert Path('tests/work/variables/INCLUDE_DIRS.log').read_text()=='work/variables/INCLUDE_DIRS.mk:3: .INCLUDE_DIRS is empty\n'
    assert '1 Test in 1 Category Failed' in Path('upstream.log').read_text()
    make=str(Path('make').resolve(strict=True)); fixture=Path('include-control.mk')
    fixture.write_text('$(info dirs=$(strip $(.INCLUDE_DIRS)))\nall:;@:\n')
    absent=subprocess.run([make,'--no-print-directory','-f',str(fixture)],text=True,capture_output=True)
    assert absent.returncode==0 and absent.stdout=='dirs=\n' and absent.stderr==''
    directory=Path('include-control');directory.mkdir();(directory/'selected.mk').write_text('ANSWER=42\n')
    fixture.write_text('$(info dirs=$(strip $(.INCLUDE_DIRS)))\ninclude selected.mk\nall:;@printf "%s\\n" "$(ANSWER)"\n')
    present=subprocess.run([make,'--no-print-directory','-I'+str(directory),'-f',str(fixture)],text=True,capture_output=True)
    assert present.returncode==0 and present.stdout=='dirs=include-control\n42\n' and present.stderr==''
    print(json.dumps({'emptyPlatformDirs':vars(absent),'explicitInclude':vars(present)},sort_keys=True),flush=True)
    result='BOUNDED_NONPASS_SANDBOX_DEFAULT_INCLUDE_DIRS'
print(json.dumps({'rawStatus':status,'classification':result,'failureDiffs':[str(p) for p in failures],
'limits':'Guile/VMS retain upstream exclusions. A bounded nonpass is not strict conformance.'},sort_keys=True),flush=True)
