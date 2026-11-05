"""Observer-only inspection of realized runtime closures against origin-audit outputs."""
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


def origin_paths(report):
    if (not isinstance(report, dict) or report.get('schema') != 1
            or report.get('failures') != [] or not isinstance(report.get('nodes'), dict)
            or not report['nodes'] or not isinstance(report.get('sourceData'), dict)):
        raise ValueError('A successful executable-origin report is required')
    known = {}
    for node in report['nodes'].values():
        if node['origin'] not in {'explicit-seed', 'pinned-source-archive', 'source-built-stage'}:
            raise ValueError('Unknown executable origin')
        for output in node['outputs'].values():
            path = output['path']
            known[path if path.startswith('/nix/store/') else '/nix/store/' + path] = node['origin']
    for path, source in report['sourceData'].items():
        if source['origin'] not in {'pinned-stage0-source-tree', 'owned-source-or-nix-generated-text'}:
            raise ValueError('Unknown source origin')
        known[path] = source['origin']
    return known


def within(value, paths):
    return any(value == p or value.startswith(p + '/') for p in paths)


def owned_executable(value, paths):
    canonical = str(PurePosixPath(value)) == value and '..' not in PurePosixPath(value).parts
    return (canonical and Path(value).is_file()
            and within(value, paths) and within(str(Path(value).resolve()), paths))


def owned_library(name, paths):
    # This bootstrap uses bare SONAMEs. A path must never discard the owned
    # prefix in a Path join, and a library symlink must stay in the closure.
    if not isinstance(name, str) or not name or '/' in name or name in {'.', '..'}:
        return False
    return any((Path(p) / 'lib' / name).is_file()
               and within(str((Path(p) / 'lib' / name).resolve()), paths) for p in paths)


def audit(report, readelf, roots):
    known = origin_paths(report)
    if not roots:
        raise ValueError('Explicit runtime roots are required')
    closure = json.loads(subprocess.check_output(['nix', 'path-info', '--json', '--recursive', *roots]))
    if isinstance(closure, dict):
        closure = [dict(v, path=k) for k, v in closure.items()]
    paths = {p['path'] for p in closure}
    failures, files = [], {}
    for root in sorted(paths):
        if root not in known:
            failures.append('unknown runtime output: ' + root)
        for file in sorted(Path(root).rglob('*')):
            if file.is_symlink():
                if not within(str(file.resolve()), paths):
                    failures.append('escaping symlink: ' + str(file))
                continue
            if not file.is_file():
                continue
            with file.open('rb') as stream:
                head = stream.read(256)
            if head.startswith(b'\x7fELF'):
                info = subprocess.check_output([readelf, '-h', '-l', '-d', str(file)], text=True)
                interpreter = re.findall(r'Requesting program interpreter: ([^\]]+)', info)
                needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', info)
                for loader in interpreter:
                    if not owned_executable(loader, paths):
                        failures.append('foreign/missing loader: ' + str(file) + ': ' + loader)
                for library in needed:
                    if not owned_library(library, paths):
                        failures.append('unresolved runtime library: ' + str(file) + ': ' + library)
                if 'Advanced Micro Devices X86-64' not in info:
                    failures.append('unexpected ELF architecture: ' + str(file))
                files[str(file)] = {'kind': 'ELF', 'interpreter': interpreter, 'needed': needed}
            elif head.startswith(b'#!'):
                shell = head.splitlines()[0][2:].decode().split()[0]
                if not owned_executable(shell, paths):
                    failures.append('foreign script interpreter: ' + str(file) + ': ' + shell)
                files[str(file)] = {'kind': 'script', 'interpreter': shell}
    return {'roots': roots, 'closure': {p: known.get(p, 'UNKNOWN') for p in sorted(paths)},
            'files': files, 'failures': failures,
            'limits': 'Runtime ELF/shebang and symlink inspection; not an upstream conformance or reproducibility proof.'}


if __name__ == '__main__':
    result = audit(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2], sys.argv[3:])
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
