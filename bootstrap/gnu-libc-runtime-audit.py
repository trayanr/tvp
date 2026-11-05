"""Exact per-generation runtime observer for the opt-in staged libc profile.

Importing predicates does not relax or change the original single-loader audit.
Source-data origin never grants executable permission.
"""
import importlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys

strict = importlib.import_module('gnu-runtime-audit')


def expand_search(entry, file):
    # Glibc's installed converter helpers use $ORIGIN. Expand only this token;
    # all resulting directories still have to belong to the exact generation.
    entry = re.sub(r'\$\{ORIGIN\}|\$ORIGIN(?=/|$)', str(file.parent), entry)
    if not entry.startswith('/') or '$' in entry:
        return None
    return str(Path(entry).resolve())


def validate(report, profile, closure):
    classified = strict.executable_outputs(report)
    known = strict.origin_paths(report)
    assignments = {}
    for name, generation in profile['generations'].items():
        roots = set(generation['executables'])
        if not roots or not roots <= classified:
            raise ValueError('Unclassified/data-only executable generation')
        if roots & assignments.keys():
            raise ValueError('Ambiguous generation assignment')
        if not strict.owned_executable(generation['loader'], roots & closure):
            raise ValueError('Loader outside selected generation')
        for root in roots:
            assignments[root] = name
        for directory in generation['search']:
            if not strict.within(directory, roots & closure):
                raise ValueError('Search outside selected generation')
    if set(profile['data']) & assignments.keys():
        raise ValueError('Data also granted executable permission')
    allowed = set(assignments) | set(profile['data'])
    if closure != allowed or not closure <= known.keys():
        raise ValueError('Closure differs from exact classified profile')
    if closure & set(report['runtimeForbiddenExecutableRoots']):
        raise ValueError('Forbidden early executable in runtime closure')
    return assignments


def audit(report, profile, closure=None):
    if closure is None:
        raw = json.loads(subprocess.check_output(['nix', 'path-info', '--json', '--recursive', *profile['roots']]))
        closure = set(raw) if isinstance(raw, dict) else {p['path'] for p in raw}
    assignments = validate(report, profile, closure)
    failures, files = [], {}
    for root in sorted(closure):
        base = Path(root)
        for file in sorted(base.rglob('*')) if base.is_dir() else [base]:
            if file.is_symlink():
                if not strict.within(str(file.resolve()), closure):
                    failures.append('Escaping symlink: ' + str(file))
                continue
            if not file.is_file():
                continue
            with file.open('rb') as stream:
                head = stream.read(256)
            if head.startswith(b'\x7fELF'):
                if root not in assignments:
                    failures.append('ELF in data root: ' + str(file))
                    continue
                name = assignments[root]
                gen = profile['generations'][name]
                permitted = set(gen['executables'])
                info = subprocess.check_output([profile['readelf'], '-h', '-l', '-d', str(file)], text=True)
                interp = re.findall(r'Requesting program interpreter: ([^\]]+)', info)
                needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', info)
                rpaths = re.findall(r'\((?:RPATH|RUNPATH)\).*\[([^\]]*)\]', info)
                raw_search = [s for group in rpaths for s in group.split(':')]
                search = [expand_search(s, file) for s in raw_search]
                order = {1: '<', 2: '>'}.get(head[5])
                if not order or struct.unpack(order + 'H', head[18:20])[0] != 62:
                    failures.append('Foreign ELF machine: ' + str(file))
                if any(i != gen['loader'] for i in interp):
                    failures.append('Wrong generation interpreter: ' + str(file))
                if any(not s or not strict.within(s, permitted) for s in search):
                    failures.append('Foreign/cross-generation search: ' + str(file))
                resolved = {n: strict.resolve_needed(n, [s for s in search if s] + gen['search'], closure, permitted) for n in needed}
                if None in resolved.values():
                    failures.append('Unresolved/cross-generation dependency: ' + str(file))
                listing = None
                if needed or interp:
                    p = subprocess.run([gen['loader'], '--list', str(file)], env={}, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                    listing = p.stdout
                    actual = re.findall(r'^\s*(\S+) => (/.*?) \(0x[0-9a-f]+\)$', listing, re.M)
                    actual = {n: str(Path(p).resolve()) for n, p in actual}
                    # The loader lists itself without 'SONAME =>', including
                    # when it appears as a DSO's explicit NEEDED dependency.
                    direct = re.findall(r'^\s*(/.*?) \(0x[0-9a-f]+\)$', listing, re.M)
                    for path in direct:
                        if path != gen['loader']:
                            failures.append('Foreign direct loader entry: ' + path)
                        actual[Path(path).name] = str(Path(path).resolve())
                    if p.returncode or any(not strict.owned_executable(p, permitted) for p in actual.values()):
                        failures.append('Foreign/failed actual loader resolution: ' + str(file))
                    if any(actual.get(n) != p for n, p in resolved.items()):
                        failures.append('Actual loader differs from declared resolution: ' + str(file))
                files[str(file)] = dict(kind='ELF', generation=name, interpreter=interp,
                    needed=resolved, search=search, rawSearch=raw_search, actualLoaderListing=listing)
            elif head.startswith(b'#!'):
                if root not in assignments:
                    failures.append('Script in data root: ' + str(file))
                    continue
                words = head.split(b'\n', 1)[0][2:].decode().split()
                interpreter = words[0] if words else ''
                if not strict.owned_executable(interpreter, set(assignments)):
                    failures.append('Foreign/data script interpreter: ' + str(file))
                files[str(file)] = dict(kind='script', interpreter=interpreter)
    return dict(schema=1, roots=profile['roots'], generations=profile['generations'],
                closure=sorted(closure), files=files, failures=sorted(set(failures)),
                limits='Exact staged GNU runtime observation, not fixed-point or full conformance.')


if __name__ == '__main__':
    report, profile = [json.loads(Path(p).read_text()) for p in sys.argv[1:3]]
    result = audit(report, profile)
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
