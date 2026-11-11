"""Classifier regressions: only the complete, sole calendar failure is allowed."""
import importlib.util
import json
from pathlib import Path
import sys


def main(path):
    spec = importlib.util.spec_from_file_location('perl_check', path)
    check = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check)
    allowed = ['Time-Local-rolling-century-1970']
    diagnostics = ''.join(
        "#   Failed test '" + name + "'\n#          got: '170'\n#     expected: '70'\n"
        for name in ('timelocal year for 1970 1 2 0 0 0', 'timegm year for 1970 1 2 0 0 0'))
    record = ('../cpan/Time-Local/t/Local.t (Wstat: 512 Tests: 187 Failed: 2)\n'
              '  Failed tests:  6, 12\n  Non-zero exit status: 2\n')
    totals = ('Files=2406, Tests=814220, 61 wallclock secs (17.75 usr  2.53 sys + 128.50 cusr  8.65 csys = 157.43 CPU)\n'
              'Result: FAIL\nmake: *** [makefile:850: test_harness] Error 2\n')
    raw = diagnostics + 'Test Summary Report\n-------------------\n' + record + totals
    assert check.known_calendar_failure(raw, 2, allowed)
    failures = {
        'no-TAP-crash': '../unexpected.t (Wstat: 256 Tests: 0 Failed: 0)\n'
                        '  Non-zero exit status: 1\n  Parse errors: No plan found in TAP output\n',
        'extra-assertion': '../unexpected.t (Wstat: 256 Tests: 1 Failed: 1)\n'
                           '  Failed tests: 1\n  Non-zero exit status: 1\n',
        'unknown-record': 'unconsumed harness diagnostic\n',
        'extra-parse-error': '  Parse errors: Bad plan\n',
    }
    results = ['sole-calendar-failure-accepted']
    for name, extra in failures.items():
        assert not check.known_calendar_failure(raw.replace(totals, extra + totals), 2, allowed), name
        results.append(name + '-rejected')
    for name, data, status, allowance in [
        ('no-allowance', raw, 2, []),
        ('wrong-status', raw, 1, allowed),
        ('changed-assertion', raw.replace('6, 12', '6, 13'), 2, allowed),
        ('invalid-totals', raw.replace('Tests=814220', 'Tests=0'), 2, allowed),
        ('malformed-timings', raw.replace('61 wallclock secs', 'Parse errors: Bad plan'), 2, allowed),
        ('duplicate-summary', raw + raw, 2, allowed),
        ('extra-trailer', raw + 'unconsumed status\n', 2, allowed),
    ]:
        assert not check.known_calendar_failure(data, status, allowance), name
        results.append(name + '-rejected')
    return results


if __name__ == '__main__':
    print(json.dumps(main(Path(sys.argv[1])), indent=2))
