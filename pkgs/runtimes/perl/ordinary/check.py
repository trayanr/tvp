"""Preserve raw upstream results; classify only the exact allowed calendar failure."""
import json
import os
import re
import subprocess
import sys


def known_calendar_failure(text, status, allowed):
    if allowed != ['Time-Local-rolling-century-1970'] or status != 2:
        return False
    summary = text.split('Test Summary Report\n')
    if len(summary) != 2:
        return False
    # Consume the entire report, including every status/parse-error record and
    # make's terminal status. No unmatched summary text may be discarded.
    report = (
        r'-{19}\n'
        r'\.\./cpan/Time-Local/t/Local\.t[ \t]+\(Wstat: 512 Tests: 187 Failed: 2\)\n'
        r'  Failed tests:[ \t]+6, 12\n'
        r'  Non-zero exit status: 2\n'
        r'Files=(?P<files>[1-9][0-9]*), Tests=(?P<tests>[1-9][0-9]*), '
        r'[0-9]+ wallclock secs \( *[0-9.]+ usr +[0-9.]+ sys \+ +'
        r'[0-9.]+ cusr +[0-9.]+ csys = +[0-9.]+ CPU\)\n'
        r'Result: FAIL\n'
        r'make: \*\*\* \[makefile:[0-9]+: test_harness\] Error 2\n\s*'
    )
    match = re.fullmatch(report, summary[1])
    return (match is not None and int(match['tests']) >= 187
            and text.count("#          got: '170'") == 2
            and text.count("#     expected: '70'") == 2
            and re.findall(r"#   Failed test '([^']+)'", text) == [
                'timelocal year for 1970 1 2 0 0 0',
                'timegm year for 1970 1 2 0 0 0'])


def main():
    allowed = json.loads(sys.argv[1])
    env = dict(os.environ, TEST_JOBS=os.environ['NIX_BUILD_CORES'])
    process = subprocess.Popen(sys.argv[2:], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, env=env)
    raw = bytearray()
    for line in process.stdout:
        sys.stdout.buffer.write(line)
        sys.stdout.buffer.flush()
        raw.extend(line)
    status = process.wait()
    if status == 0:
        print('TVP_UPSTREAM_CLASSIFICATION=PASS')
        return 0
    if known_calendar_failure(raw.decode('utf-8', errors='strict'), status, allowed):
        print('TVP_UPSTREAM_CLASSIFICATION=FAIL_KNOWN_ROLLING_CENTURY_UNWAIVED; raw exit=2; installation continues')
        return 0
    print('TVP_UPSTREAM_CLASSIFICATION=FAIL_UNEXPECTED', file=sys.stderr)
    return status


if __name__ == '__main__':
    sys.exit(main())
