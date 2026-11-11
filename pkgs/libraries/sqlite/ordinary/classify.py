"""Accept only a complete zero-error SQLite upstream run, never rewrite it."""
from pathlib import Path
import re
import sys


def classify(root):
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError('not an evidence directory')
    for name in ['exit', 'output']:
        p = root / name
        if p.is_symlink() or not p.is_file() or p.stat().st_nlink != 1:
            raise ValueError('not an independent raw evidence file')
    if (root / 'exit').read_bytes() != b'0\n':
        raise ValueError('upstream nonzero exit: UNWAIVED')
    raw = (root / 'output').read_bytes()
    if b'\0' in raw:
        raise ValueError('NUL in upstream output')
    out = raw.decode('utf-8')
    classic = re.findall(r'(?m)^([0-9]+) errors out of ([0-9]+) tests(?: on .*)?$', out)
    runner = re.findall(r'(?m)^upstream veryquick jobs=([0-9]+) cases=([0-9]+) errors=([0-9]+) unfinished=([0-9]+)$', out)
    if any(int(errors) != 0 for errors, _ in classic):
        raise ValueError('additional nonzero test summary: UNWAIVED')
    if runner:
        if len(runner) != 1 or any(int(runner[0][i]) < 1 for i in [0, 1]) or runner[0][2:] != ('0', '0'):
            raise ValueError('incomplete/failed runner summary')
    elif len(classic) != 1 or int(classic[0][0]) != 0 or int(classic[0][1]) < 1:
        raise ValueError('missing/duplicate/failed SQLite test summary')
    diagnostics = out
    runnerlog = root / 'runner.log'
    if runnerlog.exists():
        if runnerlog.is_symlink() or not runnerlog.is_file() or runnerlog.stat().st_nlink != 1:
            raise ValueError('unsafe runner log')
        extra = runnerlog.read_bytes()
        if b'\0' in extra:
            raise ValueError('NUL in runner log')
        diagnostics += '\n' + extra.decode('utf-8')
        if any(int(errors) != 0 for errors in re.findall(r'(?m)^([0-9]+) errors out of [0-9]+ tests', diagnostics)):
            raise ValueError('raw runner failure: UNWAIVED')
    if re.search(r'(?im)(segmentation fault|core dumped|bus error|^FAIL(?:ED)?\b|^Error:|^.*\.\.\.\s*FAILED\b|^not ok\b|^SQLITE-SKIP:|^.*\.\.\.\s*(?!Ok$)[A-Za-z]+$)', diagnostics):
        raise ValueError('additional failure/unknown skip: UNWAIVED')
    return 'SQLite upstream raw result accepted'


if __name__ == '__main__':
    print(classify(sys.argv[1]))
