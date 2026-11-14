"""Attr 2.5.x's exact test/attr.test requires user xattrs.

The kernel probe is independent of Attr. Return its explicit unsupported status;
otherwise exec the unchanged upstream Perl harness and preserve its result.
The privileged root/getfattr.test retains upstream's own capability decision.
"""
import os
from pathlib import Path
import subprocess
import sys

probe, runner, *arguments = sys.argv[1:]
if len(arguments) != 1:
    raise ValueError('expected one upstream Attr test file')
case = Path(arguments[0])
if case.as_posix() == 'test/attr.test':
    status = subprocess.run([probe, 'xattrs']).returncode
    if status:
        sys.exit(status if status > 0 else 1)
elif case.as_posix() != 'test/root/getfattr.test':
    raise ValueError(('unexpected Attr test', case))
os.execv(runner, [runner, *arguments])
