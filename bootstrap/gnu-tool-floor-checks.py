"""Classify exact raw checks; a new failure is a failing opt-in contract."""
import json
from pathlib import Path
import re
import sys

results = {}
for family, directory in zip(['attr', 'acl', 'coreutils', 'make', 'findutils', 'diffutils'], sys.argv[1:]):
    root = Path(directory)
    log = (root / 'make-check.log').read_text()
    status = int((root / 'make-check.status').read_text())
    summaries = [dict(zip(['total', 'pass', 'skip', 'xfail', 'fail', 'xpass', 'error'], map(int, m)))
                 for m in re.findall(r'# TOTAL:\s+(\d+)\s+# PASS:\s+(\d+)\s+# SKIP:\s+(\d+)\s+# XFAIL:\s+(\d+)\s+# FAIL:\s+(\d+)\s+# XPASS:\s+(\d+)\s+# ERROR:\s+(\d+)', log)]
    if family in {'attr', 'acl'}:
        suite = (root / 'test-suite.log').read_text()
        failures = 3 if family == 'attr' else 14
        assert status == 2 and summaries[-1]['fail'] == failures
        assert suite.count('bad interpreter: No such file or directory') == failures + (2 if family == 'acl' else 0)
        assert '/usr/bin/perl:' in suite
        classification = 'Perl harness unavailable; no executed upstream filesystem coverage'
    elif family == 'make':
        assert status == 0 and "Can't find a working Perl (perl)" in log
        classification = 'Upstream returns zero without executing its Perl regression suite'
    elif family == 'coreutils':
        suite = (root / 'tests/test-suite.log').read_text()
        assert status == 2 and re.findall(r'^FAIL: (.*)$', suite, re.M) == ['tests/install/install-C']
        block = suite.split('FAIL: tests/install/install-C\n', 1)[1].split('\nSKIP:', 1)[0]
        # Every fail assignment in this case follows the set-ID permission denial.
        assert block.count('+ fail=1') > 0
        assert block.count('+ fail=1') == block.count("Operation not permitted\n+ fail=1")
        assert summaries[-1] == dict(total=653, **{'pass':429}, skip=223, xfail=0, fail=1, xpass=0, error=0)
        classification = 'One set-ID sandbox permission failure; independent preflight recorded by installed contracts'
    else:
        assert status == 0 and summaries and all(s['fail'] == s['error'] == s['xpass'] == 0 for s in summaries)
        classification = 'Declared-prerequisite upstream subsets pass; raw skips remain visible'
    results[family] = dict(status=status, summaries=summaries, classification=classification)
print(json.dumps(results, indent=2, sort_keys=True))
