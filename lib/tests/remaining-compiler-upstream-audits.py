"""Host-only completeness controls; no compiler, Go or upstream suite runs."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap

ROOT = Path(__file__).resolve().parents[2]
GCC = ROOT/'pkgs/compilers/gcc/tests'
TOOLS = ['gcc', 'g++', 'libstdc++', 'libgomp', 'libatomic', 'libitm']


def complete(tool):
    return f'PASS: {tool} fixture\n\t\t=== {tool} Summary ===\n# of expected passes\t1\n'


full = {tool: complete(tool) for tool in TOOLS}
cases = [
    ('complete', full, True, None),
    ('one-incomplete-suite', {'gcc': 'PASS: fixture\n'}, False, None),
    ('one-completed-suite', {'gcc': complete('gcc')}, False, None),
    ('one-inconsistent-suite', {'gcc': complete('gcc').replace('\t1\n', '\t999\n')}, False, None),
    ('missing-suite', {k: v for k, v in full.items() if k != 'libitm'}, False, None),
    ('truncated-footer', full | {'gcc': 'PASS: gcc fixture\n'}, False, None),
    ('inconsistent-footer', full | {'gcc': complete('gcc').replace('\t1\n', '\t999\n')}, False, None),
    ('empty-coverage', full | {'gcc': '\t\t=== gcc Summary ===\n'}, False, None),
    ('repeated-summary', full | {'gcc': complete('gcc')*2}, False, None),
    ('results-after-summary', full | {'gcc': complete('gcc')+'PASS: late\n'}, False, None),
    ('unexpected-suite', full | {'extra': complete('extra')}, False, None),
    ('unexpected-failure', full | {'gcc': 'PASS: fixture\nFAIL: bad\n\t\t=== gcc Summary ===\n# of expected passes\t1\n# of unexpected failures\t1\n'}, False, None),
    ('json-count-mismatch', full, False, 'count'),
    ('json-suite-missing', full, False, 'suite'),
]
results = {'gcc': {}, 'go': {}, 'packageBuilds': 0, 'targetExecution': 0}
with tempfile.TemporaryDirectory(prefix='upstream-completeness-') as temp:
    workspace = Path(temp)
    for label, summaries, accepted, mutation in cases:
        raw = workspace/label
        raw.mkdir()
        for tool, data in summaries.items():
            (raw/(tool+'.sum')).write_text(data)
        subprocess.run([sys.executable, '-B', str(GCC/'summarise-upstream.py'), str(raw)], check=True, capture_output=True)
        if mutation:
            path = raw/'upstream.json'
            evidence = json.loads(path.read_text())
            if mutation == 'count': evidence['suites']['gcc.sum']['counts']['PASS'] = 2
            else: del evidence['suites']['gcc.sum']
            path.write_text(json.dumps(evidence))
        before = {p.name: p.read_bytes() for p in raw.iterdir()}
        result = subprocess.run([sys.executable, '-B', str(GCC/'audit-upstream-13.3.0.py'), str(raw/'upstream.json'), str(raw)], capture_output=True, text=True)
        assert (result.returncode == 0) == accepted, (label, result.stderr)
        assert before == {p.name: p.read_bytes() for p in raw.iterdir()}
        results['gcc'][label] = 'ACCEPTED_COMPLETE' if accepted else 'REJECTED'

    source = (ROOT/'pkgs/compilers/go/tests/upstream-ordinary.nix').read_text()
    body = textwrap.dedent(source.split("script = ''\n", 1)[1].split("    '';", 1)[0])
    go_cases = [
        ('complete', 'ALL TESTS PASSED\n', 0, True),
        ('excluded', 'ALL TESTS PASSED (some were excluded)\n', 0, False),
        ('prefixed', 'prefix ALL TESTS PASSED\n', 0, False),
        ('suffixed', 'ALL TESTS PASSED extra\n', 0, False),
        ('contradictory', 'ALL TESTS PASSED\nALL TESTS PASSED (some were excluded)\n', 0, False),
        ('empty', '', 0, False),
        ('nonzero-exit', 'ALL TESTS PASSED\n', 7, False),
        ('missing-log', None, 0, False),
    ]
    for label, log, status, accepted in go_cases:
        raw = workspace/('go-'+label)
        raw.mkdir()
        (raw/'upstream.exit').write_text(str(status)+'\n')
        if log is not None: (raw/'upstream.log').write_text(log)
        script = body.replace('${execution}', str(raw))
        assert '${' not in script
        before = {p.name: p.read_bytes() for p in raw.iterdir()}
        result = subprocess.run([shutil.which('bash'), '-euo', 'pipefail', '-c', script], text=True, capture_output=True)
        assert (result.returncode == 0) == accepted, (label, result.stderr)
        assert (result.stdout == 'passed') == accepted
        assert before == {p.name: p.read_bytes() for p in raw.iterdir()}
        results['go'][label] = 'ACCEPTED_COMPLETE' if accepted else 'REJECTED'
print(json.dumps(results, indent=2))
