"""Gate nonempty, explicitly scoped raw upstream results."""
import json
from pathlib import Path
import re
import sys
name, directory = sys.argv[1:]
root = Path(directory)
status = int((root / 'check.status').read_text())
log = (root / 'check.log').read_text()
if name == 'pkg-config':
    passed = re.findall(r'^PASS: (check-\S+)$', log, re.M)
    assert len(passed) == len(set(passed)) == 30 and 'All 30 tests passed' in log
    assert not re.search(r'^(FAIL|SKIP|XFAIL|XPASS|ERROR):', log, re.M)
    counts = {'pass': 30, 'fail': 0, 'skip': 0}
    scope = 'Complete pkg-config check/ suite; bundled GLib tests not run.'
else:
    match = re.search(r'Ran (\d+) tests? in', log)
    assert match and int(match[1]) > 0 and re.search(r'^OK$', log, re.M), log
    counts = {'pass': int(match[1]), 'fail': 0, 'skip': 0}
    scope = ('Upstream misc/ninja_syntax_test.py only. C++ ninja_test is not built: '
             'pinned Ninja archive contains no GoogleTest source and configure.py '
             'requires --gtest-source-dir. output_test.py requires script/PTY tools '
             'outside the selected BUILD floor. No full Ninja suite claim.')
assert status == 0
(root / 'classification.json').write_text(json.dumps(dict(tool=name, status=status, counts=counts, scope=scope), indent=2)+'\n')
