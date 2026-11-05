"""Summarize exact retained upstream logs without rerunning any build or test."""
import hashlib
import json
from pathlib import Path
import re
import sys

name, destination = sys.argv[1:3]
root = Path(destination)
logs = {}
for path in sorted(root.glob('*.log')):
    text = path.read_text(errors='replace')
    logs[path.name] = dict(sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                           bytes=path.stat().st_size,
                           summaryLines=[line for line in text.splitlines() if re.search(
                               r'(Files=\d|Tests=\d|Result:|All tests successful|tests? (passed|failed)|Tests Summary|# (TOTAL|PASS|SKIP|FAIL|ERROR)|test\(s\)|test cases|ALL TESTS|all.*[Oo][Kk])', line)][-100:])
statuses = {p.name: int(p.read_text()) for p in root.glob('*.status')}
assert statuses and all(v == 0 for v in statuses.values())
check = (root / (name+'.check.log')).read_text(errors='replace')
counts = dict(harness=[dict(files=int(a), tests=int(b)) for a,b in re.findall(r'Files=(\d+), Tests=(\d+)',check)],
              automake={k:int(v) for k,v in re.findall(r'^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):\s*(\d+)',check,re.M)},
              skipLines=[line for line in check.splitlines() if re.search(r'\bskipped\b',line,re.I)],
              zlibSuccessfulVariants=re.findall(r'\*\*\* (zlib .*?test OK) \*\*\*',check),
              bzip2Comparisons=len(re.findall(r'^cmp ',check,re.M)))
summary = dict(package=name, counts=counts, phases=statuses, logs=logs,
               scope=('five CLI tests: basic/help.sh, basic/version.sh, compression/basic.sh, compression/gzip-compat.sh, decompression/pass-through.sh; not full upstream coverage'
                      if name == 'zstd' else 'upstream recipe check target; raw log records skips and environment limits'),
               provenance='Copied from the successful exact package evidence output (Zstd: compilation artifact); no recompilation or rerun.')
(root/'summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
