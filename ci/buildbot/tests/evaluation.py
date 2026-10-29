"""Check catalogue evaluation in a fresh local store without building packages."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--flake', default=str(Path(__file__).resolve().parents[3]))
parser.add_argument('--system', default='x86_64-linux')
parser.add_argument('--evidence', type=Path)
args = parser.parse_args()
area = (args.evidence or Path(tempfile.mkdtemp(prefix='tvp-evaluation-'))).resolve()
area.mkdir(parents=True, exist_ok=True)
store = area / 'store'
if store.exists():
    parser.error('The evaluation store must be fresh; choose another evidence directory.')
uri = 'local?root=' + str(store)
steps = [
    ('archive', ['flake', 'archive', '--show-trace', '--to', uri, '--json', args.flake]),
    ('graph', ['eval', '--store', uri, '--show-trace', '--json', args.flake + '#graph']),
    ('check', ['flake', 'check', '--store', uri, '--show-trace', '--no-build', args.flake]),
    ('plan', ['eval', '--store', uri, '--show-trace', '--raw',
              args.flake + '#testPlans.' + args.system + '.drvPath']),
]
(area / 'commands.json').write_text(json.dumps(steps, indent=2) + '\n')
for name, command in steps:
    with (area / (name + '.out')).open('w') as output, (area / (name + '.log')).open('w') as log:
        result = subprocess.run(['nix', *command], stdout=output, stderr=log)
    if result.returncode:
        raise SystemExit(f'{name} failed; full trace: {area / (name + ".log")}')
    print(name + ': passed', flush=True)
print('Fresh-store evaluation passed. Evidence:', area)
