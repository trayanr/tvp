"""Run upstream's unmodified harness, preserving its raw FAIL/SKIP/XPASS.

Only an explicit version-definition allowance can let installation continue
past the measured rolling-century test defect. Unexpected failures stay fatal.
This classification is not an upstream PASS or an admission waiver.
"""
import json
import os
import re
import subprocess
import sys

allowed = json.loads(sys.argv[1])
env = dict(os.environ, TEST_JOBS=os.environ['NIX_BUILD_CORES'])
process = subprocess.Popen(sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
raw = bytearray()
for line in process.stdout:
    sys.stdout.buffer.write(line); sys.stdout.buffer.flush(); raw.extend(line)
status = process.wait()
if status == 0:
    print('TVP_UPSTREAM_CLASSIFICATION=PASS')
    sys.exit(0)
text = raw.decode('utf-8', errors='strict')
# Restrict the complete summary, diagnostics, statuses and exact assertion IDs.
summary = text.split('Test Summary Report\n')
failures = re.findall(r'^([^\n]+?)\s+\(Wstat: (\d+) Tests: (\d+) Failed: (\d+)\)\n\s+Failed tests:\s+([^\n]+)', summary[-1], re.M)
expected = [('../cpan/Time-Local/t/Local.t', '512', '187', '2', '6, 12')]
known = (allowed == ['Time-Local-rolling-century-1970'] and status == 2
         and len(summary) == 2 and failures == expected
         and text.count("#          got: '170'") == 2
         and text.count("#     expected: '70'") == 2
         and re.findall(r"#   Failed test '([^']+)'", text) == [
             'timelocal year for 1970 1 2 0 0 0', 'timegm year for 1970 1 2 0 0 0']
         and 'Result: FAIL' in summary[-1])
if known:
    print('TVP_UPSTREAM_CLASSIFICATION=FAIL_KNOWN_ROLLING_CENTURY_UNWAIVED; raw exit=2; installation continues')
    sys.exit(0)
print('TVP_UPSTREAM_CLASSIFICATION=FAIL_UNEXPECTED', file=sys.stderr)
sys.exit(status)
