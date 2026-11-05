"""Observer-only inspection of realized runtime closures against origin-audit outputs."""
import json
from pathlib import Path
from pathlib import PurePosixPath
import re
import subprocess
import sys

report = json.loads(Path(sys.argv[1]).read_text())
known = {o['path'] if o['path'].startswith('/nix/store/') else '/nix/store/' + o['path']: n['origin']
         for n in report['nodes'].values() for o in n['outputs'].values()}
known.update({p: n['origin'] for p, n in report['sourceData'].items()})
readelf = sys.argv[2]
roots = sys.argv[3:]
closure = json.loads(subprocess.check_output(['nix', 'path-info', '--json', '--recursive', *roots]))
if isinstance(closure, dict):
    closure = [dict(v, path=k) for k, v in closure.items()]
paths = {p['path'] for p in closure}
failures, files = [], {}


def owned_executable(value):
    canonical = str(PurePosixPath(value)) == value and '..' not in PurePosixPath(value).parts
    target = str(Path(value).resolve())
    return (canonical and Path(value).is_file()
            and any(value.startswith(p + '/') for p in paths)
            and any(target.startswith(p + '/') for p in paths))


for root in sorted(paths):
    if root not in known:
        failures.append('unknown runtime output: ' + root)
    for file in sorted(Path(root).rglob('*')):
        if file.is_symlink():
            target = str(file.resolve())
            if not any(target == p or target.startswith(p + '/') for p in paths):
                failures.append('escaping symlink: ' + str(file))
            continue
        if not file.is_file():
            continue
        with file.open('rb') as f:
            head = f.read(256)
        if head.startswith(b'\x7fELF'):
            info = subprocess.check_output([readelf, '-h', '-l', '-d', str(file)], text=True)
            interpreter = re.findall(r'Requesting program interpreter: ([^\]]+)', info)
            needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', info)
            for loader in interpreter:
                if not owned_executable(loader):
                    failures.append('foreign/missing loader: ' + str(file) + ': ' + loader)
            for lib in needed:
                if not any((Path(p) / 'lib' / lib).is_file() for p in paths):
                    failures.append('unresolved runtime library: ' + str(file) + ': ' + lib)
            if 'Advanced Micro Devices X86-64' not in info:
                failures.append('unexpected ELF architecture: ' + str(file))
            files[str(file)] = {'kind': 'ELF', 'interpreter': interpreter, 'needed': needed}
        elif head.startswith(b'#!'):
            shell = head.splitlines()[0][2:].decode().split()[0]
            if not owned_executable(shell):
                failures.append('foreign script interpreter: ' + str(file) + ': ' + shell)
            files[str(file)] = {'kind': 'script', 'interpreter': shell}
result = {'roots': roots, 'closure': {p: known.get(p, 'UNKNOWN') for p in sorted(paths)},
          'files': files, 'failures': failures,
          'limits': 'Runtime ELF/shebang and symlink inspection; not an upstream conformance or reproducibility proof.'}
print(json.dumps(result, indent=2, sort_keys=True))
sys.exit(bool(failures))
