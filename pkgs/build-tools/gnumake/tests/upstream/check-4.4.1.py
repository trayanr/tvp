"""Classify the complete raw Make suite: clean or the measured libc PATH defect.

Never require a failure. Any other failure remains fatal. The original checker
and frozen consumers retain their old identity.
"""
from pathlib import Path
import json
import sys

status = int(sys.argv[1])
log = Path('upstream.log').read_text()
failures = sorted(Path('tests/work').rglob('*.diff*'))
expected = Path('tests/work/misc/general4.diff.9')
if status == 0:
    assert not failures, failures
    result = 'PASS'
else:
    assert failures == [expected], (status, failures)
    assert Path('tests/work/misc/general4.base.9').read_text() == 'hi\n'
    assert Path('tests/work/misc/general4.log.9').read_text() == (
        'make: echo: No such file or directory\n'
        'make: *** [work/misc/general4.mk.9:2: a] Error 127\n'
    )
    assert '1 Test in 1 Category Failed' in log
    result = 'BOUNDED_NONPASS_LIBC_DEFAULT_PATH'
for path in failures:
    print(f'RAW FAILURE {path}:\n{path.read_text()}')
print(json.dumps({'rawStatus': status, 'classification': result,
                  'failureDiffs': [str(p) for p in failures],
                  'limits': 'Guile and VMS cases retain upstream exclusions; no strict-conformance claim for a nonpass.'}, sort_keys=True))
