"""Fail closed on raw upstream failure, absent summaries or unreviewed records.

Known corpus mismatches are still UNWAIVED; they are not made passing. Changing
this input replays the preserved artifact without executing make or recompiling.
"""
import json
from pathlib import Path
import re
import sys


def classify(root, version):
    root = Path(root)
    record = json.loads((root/'exit.json').read_text())
    if type(record['exit']) is not int or record['exit'] != 0:
        raise ValueError(('unqualified upstream exit', record['exit']))
    text = (root/'stdout').read_text(encoding='utf-8', errors='strict')
    if not re.search(r'^Total [1-9][0-9]* tests, no errors$', text, re.M):
        raise ValueError('missing positive upstream test summary')
    if re.search(r'(?i)\b(fail(?:ed|ure|ures)?|xpass|segmentation|core dumped|aborted)\b|\b[1-9][0-9]* (?:errors|leaks)\b', text):
        raise ValueError('raw upstream nonpass remains UNWAIVED')
    # Operational logs can contain diagnostics from intentionally invalid inputs.
    # No blanket acceptance: until their exact body is reviewed, retain as a gap.
    for name in ('runsuite.log', 'runtest.log', 'test-suite.log'):
        p = root/name
        if p.exists() and p.read_bytes().strip():
            body = p.read_text(encoding='utf-8', errors='strict')
            rng = [int(x) for x in re.findall(r'Failed to detect incorrect RNG line (\d+)', body)]
            instances = [int(x) for x in re.findall(r'Failed to validate valid instance line (\d+)', body)]
            if version == '2.15.3' and rng == [616,759,775,784,793,874,6583] and instances == [3799,3958,3961]:
                raise ValueError('known strict corpus failure UNWAIVED; missing XSTC coverage remains')
            raise ValueError(('unreviewed upstream log body', name))
    # Source staging has no immutable real make-output body contracts yet.
    # Only the narrow summary protocol is currently recognized; command echoes,
    # extra records and new skips require parent source review plus replay of
    # measured raw evidence. Never infer that an unknown body passed from exit0.
    for line in text.splitlines():
        if not re.fullmatch(r'(?:Total|Ran) [1-9][0-9]* tests(?: \([0-9]+ schemata\))?, no errors', line):
            raise ValueError(('unreviewed raw output record', line))
    return {'exit': 0, 'summaryPresent': True}


if __name__ == '__main__':
    print(json.dumps(classify(sys.argv[1], sys.argv[2]), sort_keys=True))
