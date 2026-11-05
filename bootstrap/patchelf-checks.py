"""Keep the pinned fixture failure explicit; reject every unclassified result."""
from collections import Counter
import json
from pathlib import Path
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def summary(text, expected):
    keys = 'TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR'
    lines = [line for line in text.splitlines()
             if re.match(r'^\s*#\s*(?:' + keys + r')\s*:', line)]
    rows = [re.fullmatch(r'# (' + keys + r'):[ \t]+(\d+)[ \t]*', line) for line in lines]
    require(all(rows), 'Malformed summary field')
    rows = [match.groups() for match in rows]
    require(len(rows) == 7 and len(dict(rows)) == 7, 'Missing or repeated summary')
    counts = {key: int(value) for key, value in rows}
    require(counts == expected, 'Unexpected upstream summary: ' + str(counts))
    return counts


def results(paths):
    observed = {}
    for path in paths:
        lines = [line for line in path.read_text().splitlines()
                 if line.lstrip().startswith(':test-result')]
        rows = [re.fullmatch(r':test-result: (\S+)[ \t]*', line) for line in lines]
        require(len(rows) == 1 and rows[0] is not None
                and rows[0][1] in {'PASS', 'SKIP', 'FAIL', 'XFAIL', 'XPASS', 'ERROR'},
                'Malformed test result: ' + str(path))
        name = path.name.removesuffix('.trs')
        require(name not in observed, 'Duplicate test result: ' + str(path))
        observed[name] = rows[0][1]
    return observed


def classify(mode, location, status, extra):
    selected = ['no-rpath.sh', 'shared-rpath.sh', 'replace-add-needed.sh']
    if mode == 'full':
        expected = dict(TOTAL=71, PASS=66, SKIP=4, XFAIL=0, FAIL=1, XPASS=0, ERROR=0)
        counts = summary((location / 'test-suite.log').read_text(), expected)
        observed = results(sorted(location.rglob('*.trs')))
        # The pinned TESTS list includes empty-note.sh twice; Automake counts
        # its one result twice in the summary, while .trs files remain unique.
        require(status == 2 and len(observed) == 70, 'Unexpected full-suite status or coverage')
        require(observed.get('empty-note.sh') == 'PASS', 'Repeated upstream test did not pass')
        require(Counter(observed.values()) == Counter(PASS=65, SKIP=4, FAIL=1),
                'Individual results differ from full summary')
        require([name for name, value in observed.items() if value == 'FAIL'] == ['no-rpath.sh'],
                'Unclassified test failure')
        skips = {'set-rpath-rel-map.sh', 'remove-rld-map-rel.sh',
                 'short-first-segment.sh', 'large-page-dynamic.sh'}
        require({name for name, value in observed.items() if value == 'SKIP'} == skips,
                'Unclassified skipped coverage')
        fixture = re.search(r'File: tests/no-rpath\n(.*?)(?:\nFile:|\Z)', extra.read_text(), re.S)
        require(fixture is not None and re.search(r'\((?:RPATH|RUNPATH)\).*\[[^\]\n]+\]', fixture[1]),
                'Missing nonempty initial fixture RPATH')
        return dict(classificationAccepted=True, rawSuitePass=False, summary=counts,
                    uniqueResults=70, repeatedUpstreamTest='empty-note.sh',
                    fixtureFailure='no-rpath.sh', qualification='Initial compiler RPATH violates fixture premise; supplemental recheck remains separate.')
    require(mode == 'recheck', 'Unknown classification mode')
    expected = dict(TOTAL=3, PASS=3, SKIP=0, XFAIL=0, FAIL=0, XPASS=0, ERROR=0)
    counts = summary(location.read_text(), expected)
    observed = results([extra / (name + '.trs') for name in selected])
    require(status == 0 and observed == dict.fromkeys(selected, 'PASS'),
            'Supplemental fixture checks did not all execute and pass')
    return dict(classificationAccepted=True, summary=counts, selected=selected,
                qualification='Supplemental fixture checks only, not full-suite conformance.')


if __name__ == '__main__':
    require(len(sys.argv) == 5, 'Expected mode, results, status file and fixture input')
    print(json.dumps(classify(sys.argv[1], Path(sys.argv[2]),
                              int(Path(sys.argv[3]).read_text()), Path(sys.argv[4])), indent=2))
