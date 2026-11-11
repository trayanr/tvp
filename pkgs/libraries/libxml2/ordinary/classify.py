"""Fail closed on raw upstream failure, absent summaries or unreviewed records.

Known corpus mismatches are still UNWAIVED; they are not made passing. Changing
this input replays the preserved artifact without executing make or recompiling.
"""
import json
from pathlib import Path
import re
import stat
import sys


def read_record(path):
    state = path.lstat()
    if not stat.S_ISREG(state.st_mode) or state.st_nlink != 1:
        raise ValueError(('unexpected raw record node', str(path)))
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(('duplicate raw record key', key))
            value[key] = item
        return value
    value = json.loads(path.read_text(), object_pairs_hook=unique)
    if not isinstance(value, dict):
        raise ValueError('upstream result record must be an object')
    return value


def classify(root, version):
    root = Path(root)
    if not root.is_absolute() or str(root) != str(root.resolve(strict=True)):
        raise ValueError('canonical raw capture directory required')
    record = read_record(root/'exit.json')
    if (set(record) != {'argv', 'exit'} or not isinstance(record['argv'], list)
            or not record['argv'] or not all(isinstance(a, str) and a for a in record['argv'])
            or type(record['exit']) is not int or record['exit'] != 0):
        raise ValueError(('unqualified upstream exit', record.get('exit')))
    commands = root/'commands'
    if commands.is_symlink() or not commands.is_dir():
        raise ValueError('missing per-command upstream capture')
    units = list(commands.iterdir())
    if not units:
        raise ValueError('no upstream commands captured')
    for unit in units:
        if unit.is_symlink() or not unit.is_dir():
            raise ValueError('unexpected upstream command node')
        result = read_record(unit/'exit.json')
        if (set(result) != {'argv', 'cwd', 'exit'} or type(result['exit']) is not int
                or result['exit'] != 0 or not isinstance(result['argv'], list)
                or not result['argv'] or not all(isinstance(a, str) and a for a in result['argv'])
                or not isinstance(result['cwd'], str) or not result['cwd'].startswith('/')):
            raise ValueError(('unqualified upstream command', unit.name))
        output = unit/'stdout'
        if output.is_symlink() or not output.is_file() or output.stat().st_nlink != 1:
            raise ValueError('missing/aliased upstream command output')
    text = (root/'stdout').read_text(encoding='utf-8', errors='strict')
    if not re.search(r'^Total [1-9][0-9]* tests, no errors$', text, re.M):
        raise ValueError('missing positive upstream test summary')
    if re.search(r'(?i)\b(fail(?:ed|ure|ures)?|xpass|segmentation|core dumped|aborted)\b|\b[1-9][0-9]* (?:errors|leaks)\b', text):
        raise ValueError('raw upstream nonpass remains UNWAIVED')
    # Operational logs can contain diagnostics from intentionally invalid inputs.
    # No blanket acceptance: until their exact body is reviewed, retain as a gap.
    for name in ('runsuite.log', 'runtest.log', 'runxmlconf.log', 'test-suite.log'):
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
    return {'exit': 0, 'summaryPresent': True, 'commandsCaptured': len(units)}


if __name__ == '__main__':
    print(json.dumps(classify(sys.argv[1], sys.argv[2]), sort_keys=True))
