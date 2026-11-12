"""Reserve native SHELL_PATH strings; keep generator SHELL_PATH executable.

Test programs are private upstream construction, not production prerequisites.
The complete public commands/templates remain in upstream's all/install targets.
"""
from pathlib import Path
p = Path('Makefile')
s = p.read_text()
lines = s.splitlines(keepends=True)
found = 0
for i, line in enumerate(lines):
    if line.startswith('SHELL_PATH_CQ = '):
        assert line.endswith('"\n'), line
        lines[i] = line[:-2] + r'\0TVP_ORDINARY_SHELL_' + 'X' * 238 + '"\n'
        found += 1
assert found == 1
s = ''.join(lines)
line = 'all:: $(TEST_PROGRAMS) $(test_bindir_programs) $(UNIT_TEST_PROGS) $(CLAR_TEST_PROG)\n'
assert s.count(line) == 1
p.write_text(s.replace(line, '# Test programs are built by the independent upstream factory.\n'))
