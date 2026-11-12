"""Accept only complete GCC13 C/C++ summaries with no unexpected outcomes.

The raw-summary completion checks match audit-upstream.py. GCC16's reproduced
failure allowances are deliberately separate from this strict GCC13 endpoint.
"""
import collections
import json
from pathlib import Path
import re
import sys


raw = json.loads(Path(sys.argv[1]).read_text())
root = Path(sys.argv[2])
assert raw['schema'] == 1
suites = raw['suites']
tools = ['gcc', 'g++', 'libstdc++', 'libgomp', 'libatomic', 'libitm']
assert collections.Counter(Path(name).stem for name in suites) == collections.Counter(tools), 'Incomplete GCC13 suite set'
assert {str(p.relative_to(root)) for p in root.rglob('*.sum')} == set(suites), 'Raw summary inventory disagrees with JSON'
footer_tags = {
    'expected passes': 'PASS', 'unexpected failures': 'FAIL',
    'unexpected successes': 'XPASS', 'expected failures': 'XFAIL',
    'unsupported tests': 'UNSUPPORTED', 'unresolved testcases': 'UNRESOLVED',
    'untested testcases': 'UNTESTED', 'errors': 'ERROR',
    'warning messages': 'WARNING',
}
result_tags = 'PASS|FAIL|XPASS|XFAIL|UNSUPPORTED|UNRESOLVED|UNTESTED|ERROR|WARNING'
totals = collections.Counter()
for name, suite in suites.items():
    text = (root / name).read_text()
    tool = Path(name).stem
    headers = list(re.finditer(r'^[ \t]*=== ' + re.escape(tool) + r' Summary ===[ \t]*$', text, re.M))
    assert len(headers) == 1, (name, 'Missing or repeated completed summary')
    records = re.findall(r'^(' + result_tags + r'): (.*)$', text, re.M)
    observed = collections.Counter(tag for tag, _ in records)
    assert observed['PASS'] > 0, (name, 'No passing coverage')
    assert observed == suite['counts'], (name, 'Raw records disagree with JSON')
    unexpected = collections.Counter(tag + ': ' + case for tag, case in records
                                     if tag in {'FAIL', 'XPASS', 'UNRESOLVED', 'ERROR'})
    assert unexpected == collections.Counter(suite['unexpected']), (name, 'Raw unexpected outcomes disagree with JSON')
    tail = text[headers[0].end():]
    assert not re.search(r'^(' + result_tags + r'): ', tail, re.M), (name, 'Results follow summary')
    footer = collections.Counter()
    for label, value in re.findall(r'^# of (.+?)[ \t]+([0-9]+)[ \t]*$', tail, re.M):
        assert label in footer_tags, (name, label)
        tag = footer_tags[label]
        assert tag not in footer, (name, 'Repeated summary total', tag)
        footer[tag] = int(value)
    assert footer == observed, (name, 'Completed summary totals disagree with raw records')
    assert not unexpected, (name, 'Unclassified raw GCC13 outcomes')
    totals.update(observed)
print(json.dumps({'strictUpstreamConformance': True, 'completedRawSummaryCount': len(suites), 'rawCounts': dict(totals)}, indent=2))
