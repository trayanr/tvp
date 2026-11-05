"""Retain raw upstream logs independently of finalized library references."""
import json
from pathlib import Path
import re
import shutil
import sys

mode, name, directory = sys.argv[1:4]
root = Path(directory)
if mode == 'capture':
    dest = Path(sys.argv[4])
    for p in [root / 'config.log', *root.rglob('*.log'), *root.rglob('*.trs')]:
        if p.is_file() and '.tvp-evidence' not in p.parts:
            target = dest / 'upstream' / p.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, target)
    if name == 'gmp':
        shutil.copyfile(root / 'gmp.h', dest / 'gmp.h.original')
else:
    status = int((root / 'check.status').read_text())
    log = (root / 'check.log').read_text()
    summaries = [dict(zip(('total', 'pass', 'skip', 'xfail', 'fail', 'xpass', 'error'), map(int, m)))
                 for m in re.findall(r'# TOTAL:\s*(\d+)\s*# PASS:\s*(\d+)\s*# SKIP:\s*(\d+)\s*# XFAIL:\s*(\d+)\s*# FAIL:\s*(\d+)\s*# XPASS:\s*(\d+)\s*# ERROR:\s*(\d+)', log)]
    old = [int(n) for n in re.findall(r'All (\d+) tests passed', log)]
    result = dict(library=name, upstreamExitStatus=status, automakeSummaries=summaries,
                  legacyPassedGroups=old, rawLog='check.log',
                  testRecords=len(list(root.rglob('*.trs'))))
    (root / 'classification.json').write_text(json.dumps(result, indent=2) + '\n')
    if status or not (summaries or old) or any(s['fail'] or s['error'] or s['xpass'] for s in summaries):
        raise ValueError(f'Unclassified or failed upstream suite: {result}')
