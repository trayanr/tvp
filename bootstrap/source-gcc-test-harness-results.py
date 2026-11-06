"""Reject incomplete/nonzero DejaGNU runs and disagreeing log/sum records."""
from collections import Counter
from pathlib import Path
import re

LABELS = {'PASS': 'expected passes', 'FAIL': 'unexpected failures',
          'XFAIL': 'expected failures', 'XPASS': 'unexpected successes',
          'UNRESOLVED': 'unresolved testcases', 'UNSUPPORTED': 'unsupported tests',
          'UNTESTED': 'untested testcases', 'ERROR': 'framework errors'}


def inspect(root, status, *, successful=True, tool="tvp"):
    root = Path(root)
    texts = [(root / (tool + '.' + suffix)).read_text() for suffix in ['sum', 'log']]
    counts = []
    for index, text in enumerate(texts):
        assert re.search(r'^\s*=== ' + re.escape(tool) + r' Summary ===\s*$', text, re.M), 'missing summary'
        if index == 1:
            assert re.search(r'^runtest completed at ', text, re.M), 'missing completion footer'
        records = Counter(re.findall(r'^(PASS|FAIL|XFAIL|XPASS|UNRESOLVED|UNSUPPORTED|UNTESTED|ERROR):', text, re.M))
        assert records and records['PASS'], 'empty suite'
        for key, label in LABELS.items():
            footer = re.findall(r'^# of ' + label + r'\s+(\d+)\s*$', text, re.M)
            # DejaGNU 1.6.3 emits ERROR diagnostics without a numeric footer.
            if key == 'ERROR':
                continue
            assert len(footer) <= 1 and int(footer[0] if footer else 0) == records[key], (key, records, footer)
        counts.append(records)
    assert counts[0] == counts[1], 'sum/log disagreement'
    if successful:
        assert status == 0, 'nonzero runner'
        assert not any(counts[0][x] for x in ['FAIL', 'XPASS', 'UNRESOLVED', 'ERROR']), counts[0]
    return dict(status=status, counts=dict(counts[0]), complete=True)
