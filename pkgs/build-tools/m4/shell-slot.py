from pathlib import Path
import sys
p=Path(sys.argv[1])
assert not p.is_symlink() and p.resolve(strict=True).is_relative_to(Path.cwd().resolve()), p
assert p.stat().st_nlink == 1, p
s=p.read_text()
lines=s.splitlines(keepends=True)
found=0
for i,line in enumerate(lines):
    if line.startswith('#define SYSCMD_SHELL '):
        assert line.rstrip().endswith('"')
        lines[i]=line.rstrip()[:-1]+r'\0TVP_ORDINARY_SHELL_'+ 'X'*238+'"\n'
        found+=1
assert found==1
p.write_text(''.join(lines))
