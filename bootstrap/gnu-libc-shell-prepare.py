"""Patch only the selected libc shell constants, recording all source uses."""
import json
from pathlib import Path
import re
import sys

root, shell = Path(sys.argv[1]), sys.argv[2]
if not re.fullmatch(r'/nix/store/[a-z0-9]{32}-tvp-bootstrap-gnu-bash-5\.3/bin/sh', shell):
    raise ValueError('Expected exact prior source-built GNU Bash')
sites = {
    'sysdeps/posix/system.c': '#define\tSHELL_PATH\t"/bin/sh"',
    'sysdeps/generic/paths.h': '#define\t_PATH_BSHELL\t"/bin/sh"',
    'sysdeps/unix/sysv/linux/paths.h': '#define\t_PATH_BSHELL\t"/bin/sh"',
}
uses = {}
for p in sorted(root.rglob('*')):
    if p.suffix not in {'.c', '.h'} or not p.is_file():
        continue
    lines = p.read_text(errors='replace').splitlines()
    matches = [dict(line=i, text=line) for i, line in enumerate(lines, 1)
               if re.search(r'_PATH_BSHELL|SHELL_PATH|"/bin/(?:ba)?sh"', line)]
    if matches:
        uses[str(p.relative_to(root))] = matches
for name, old in sites.items():
    p = root / name
    text = p.read_text()
    if text.count(old) != 1:
        raise ValueError('Pinned shell site changed: ' + name)
    p.write_text(text.replace(old, old.replace('/bin/sh', shell)))
print(json.dumps(dict(shell=shell, patched=sites, sourceUses=uses), indent=2, sort_keys=True))
