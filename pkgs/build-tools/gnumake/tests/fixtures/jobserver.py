"""Measure real nested Make scheduling, including the serial negative control."""
from pathlib import Path
import fcntl
import json
import os
import subprocess
import sys
import time

if sys.argv[1] == 'worker':
    state = Path('state.json')
    def update(delta):
        with open('state.lock', 'a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            row = json.loads(state.read_text())
            row['active'] += delta
            row['maximum'] = max(row['maximum'], row['active'])
            if delta < 0:
                row['completed'] += 1
            state.write_text(json.dumps(row))
    update(1)
    time.sleep(0.15)
    update(-1)
else:
    make, python = sys.argv[1:]
    fixture = str(Path(__file__).resolve())
    Path('Makefile').write_text('all:\n\t+@$(MAKE) --no-print-directory -f child.mk\n')
    Path('child.mk').write_text('all: a b c d e f\na b c d e f:\n\t+@$(MAKE) --no-print-directory -f leaf.mk\n')
    Path('leaf.mk').write_text(f'all:\n\t@{python} {fixture} worker\n')
    for jobs in [2, 1]:
        Path('state.json').write_text(json.dumps({'active': 0, 'maximum': 0, 'completed': 0}))
        subprocess.run([make, '--no-print-directory', f'-j{jobs}', '--output-sync=target'],
                       env={'PATH': '/absent'}, check=True, timeout=30)
        state = json.loads(Path('state.json').read_text())
        assert state == {'active': 0, 'maximum': jobs, 'completed': 6}, (jobs, state)
        print(f'nested jobserver -j{jobs}: {state}', file=sys.stderr)
