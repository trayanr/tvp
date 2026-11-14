"""Private test metadata preparation; never configure or install production."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(sys.argv[1])
protocol = sys.argv[2]
bash = sys.argv[3]
if root.is_symlink() or root.resolve() != root or not root.is_absolute():
    raise ValueError('not a private canonical tree')
# The 3.0.0 test instrumentation adds pragma.c to TESTSRC in Makefile.in.
# config.status performs only the saved substitutions; it does not configure.
if protocol == 'quick' and (root / 'Makefile.in').stat().st_mtime_ns > (root / 'Makefile').stat().st_mtime_ns:
    subprocess.run([bash, './config.status', 'Makefile'], cwd=root, check=True)
# Prevent make's reconfigure rules from firing due solely to extraction/patch
# ordering. Modern patches do not change configured metadata. Refuse unknown
# modern Makefile.in changes instead of silently reconfiguring with new prefixes.
if protocol == 'veryquick':
    if (root / 'Makefile.in').stat().st_mtime_ns > (root / 'Makefile').stat().st_mtime_ns:
        raise ValueError('modern Makefile.in changed: needs explicit private substitution protocol')
# config.status may emit an older timestamp than a same-tick patched input.
makefile = root / 'Makefile'
newest = max(p.stat().st_mtime_ns for p in [makefile, root / 'Makefile.in', root / 'auto.def'] if p.exists())
os.utime(makefile, ns=(newest, newest))
