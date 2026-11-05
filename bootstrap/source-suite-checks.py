"""Gate raw nonempty suite counts and the exact known decimal-float skips."""
import json
from pathlib import Path
import sys

name, directory = sys.argv[1:]
root = Path(directory)
result = json.loads((root / 'classification.json').read_text())
expected_total, expected_pass = {'gmp': (200, 200), 'mpfr': (198, 196), 'mpc': (75, 75)}[name]
expected_skips = {'tget_set_d64', 'tget_set_d128'} if name == 'mpfr' else set()
records = {}
for p in root.rglob('*.trs'):
    statuses = [s.removeprefix(':test-result: ') for s in p.read_text().splitlines()
                if s.startswith(':test-result: ')]
    if len(statuses) != 1 or str(p.relative_to(root)) in records:
        raise ValueError('Ambiguous upstream test record: ' + str(p))
    records[str(p.relative_to(root))] = statuses[0]
skips = {Path(n).stem for n, status in records.items() if status == 'SKIP'}
assert result['upstreamExitStatus'] == 0
assert len(records) == expected_total
assert sum(s['total'] for s in result['automakeSummaries']) == expected_total
assert sum(s['pass'] for s in result['automakeSummaries']) == expected_pass
assert sum(s['skip'] for s in result['automakeSummaries']) == len(expected_skips)
assert skips == expected_skips
assert all(s == 'PASS' or (s == 'SKIP' and Path(n).stem in expected_skips) for n, s in records.items())
result.update(rawCounts={'total': len(records), 'pass': expected_pass, 'skip': len(skips)},
              skips=sorted(skips), skipReason='GCC has no decimal float support' if skips else None)
(root / 'classification.json').write_text(json.dumps(result, indent=2) + '\n')
