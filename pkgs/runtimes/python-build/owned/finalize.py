"""Temporarily permit owned output transforms; restore installed modes on failure too."""
from pathlib import Path
import stat
import subprocess
import sys
root = Path(sys.argv[1])
modes = {p: stat.S_IMODE(p.stat().st_mode) for p in root.rglob('*')
         if p.is_file() and not p.is_symlink()}
try:
    for p, mode in modes.items():
        p.chmod(mode | stat.S_IWUSR)
    subprocess.run([sys.argv[3], '-euc', sys.argv[2]], check=True)
finally:
    for p, mode in modes.items():
        p.chmod(mode)
