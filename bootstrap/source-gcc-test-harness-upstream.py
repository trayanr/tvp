"""Validate nonempty upstream evidence without laundering nested test controls."""
from collections import Counter
import json
from pathlib import Path
import re
import sys


def inspect(name, root):
    root = Path(root)
    status = int((root/(name+'.check.status')).read_text())
    text = (root/(name+'.check.log')).read_text()
    assert status == 0, (name, status)
    if name in ['tcl', 'expect']:
        summaries = re.findall(r'^all.tcl:\s+Total\s+(\d+)\s+Passed\s+(\d+)\s+Skipped\s+(\d+)\s+Failed\s+(\d+)', text, re.M)
        assert len(summaries) == 1, (name, 'missing/duplicate summary')
        total, passed, skipped, failed = map(int, summaries[0])
        assert total > 0 and passed > 0 and total == passed+skipped+failed and failed == 0
        if name == 'tcl':
            assert 'Tests ended at ' in text and 'Sourced 152 Test Files.' in text
            assert len(re.findall(r'^\+\+\+\+ .* PASSED$', text, re.M)) == passed
            printed_skips = re.findall(r'^\+\+\+\+ (.*) SKIPPED:', text, re.M)
            # tcltest-25.1 deliberately nests an uncounted constraint probe.
            assert '++++ tcltest-25.1 PASSED' in text
            assert printed_skips.count('tcltest-25.1.0') == 1
            assert len(printed_skips)-1 == skipped
        else:
            # Expect's all.tcl catches file sourcing errors. Require every
            # distributed test file and reject its uncounted error diagnostics.
            for file in ['cat', 'expect', 'logfile', 'pid', 'send', 'spawn', 'stty']:
                assert file+'.test' in text
            assert not re.search(r'(?im)invalid command|couldn.t|error:|no such file|spawn id .*not open', text)
        constraints = dict((key, int(number)) for number, key in re.findall(r'^\s+(\d+)\t([^\n]+)$', text, re.M))
        return dict(status=status, total=total, passed=passed, skipped=skipped, failed=failed, constraints=constraints)
    tools = {}
    for tool in ['launcher', 'libdejagnu', 'report-card', 'runtest']:
        files = [root/'raw/build'/(tool+'.'+suffix) for suffix in ['sum','log']]
        texts = [p.read_text() for p in files]
        counts = Counter(re.findall(r'^(PASS|FAIL|XPASS|XFAIL|UNRESOLVED|UNSUPPORTED|UNTESTED|ERROR):', texts[0], re.M))
        assert counts['PASS'] > 0 and not any(counts[x] for x in ['FAIL','XPASS','UNRESOLVED','ERROR'])
        assert 'runtest completed at ' in texts[1]
        for value in texts:
            summary = value[value.rindex('=== '+tool+' Summary ==='):]
            assert int(re.search(r'# of expected passes\s+(\d+)', summary)[1]) == counts['PASS']
            assert not re.search(r'# of (unexpected failures|unexpected successes|unresolved testcases)', summary)
        tools[tool] = dict(counts=dict(counts), complete=True,
                          logScope='Final footer agrees with sum records; log additionally contains intentional nested child output')
    assert sum(x['counts']['PASS'] for x in tools.values()) > 500
    return dict(status=status, tools=tools)


if __name__ == '__main__':
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    result = {name: inspect(name, root) for name, root in json.loads(sys.argv[2]).items()}
    (out/'summary.json').write_text(json.dumps(result, sort_keys=True, indent=2)+'\n')
