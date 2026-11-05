"""Strict GNU runtime observer. Source data never authorizes an executable."""
import json
from pathlib import Path
import re
import subprocess
import sys
import struct
from pathlib import PurePosixPath


def origin_paths(report):
    if (not isinstance(report, dict) or report.get('schema') != 1
            or report.get('failures') != [] or not isinstance(report.get('nodes'), dict)
            or not report['nodes'] or not isinstance(report.get('sourceData'), dict)
            or not isinstance(report.get('runtimeForbiddenExecutableRoots'), list)):
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
    if any(path not in known for path in report['runtimeForbiddenExecutableRoots']):
        raise ValueError('Unknown early executable root')
    return known


def within(value, paths):
    return any(value == p or value.startswith(p + '/') for p in paths)


def owned_executable(value, paths):
    canonical = str(PurePosixPath(value)) == value and '..' not in PurePosixPath(value).parts
    return (canonical and Path(value).is_file()
            and within(value, paths) and within(str(Path(value).resolve()), paths))


def executable_outputs(report):
    origin_paths(report)  # validate successful, classified origin report
    return {p['path'] if p['path'].startswith('/nix/store/') else '/nix/store/' + p['path']
            for node in report['nodes'].values() if node['origin'] == 'source-built-stage'
            for p in node['outputs'].values()}


def gnu_interpreter(value, loader, executable_roots):
    return value == loader and owned_executable(value, executable_roots)


def resolve_needed(name, search, closure, executable_roots):
    if not isinstance(name, str) or not name or '/' in name or name in {'.', '..'}:
        return None
    for directory in search:
        candidate = Path(directory) / name
        if candidate.is_file():
            resolved = str(candidate.resolve())
            if within(resolved, closure & executable_roots):
                return resolved
            return None
    return None


def audit(report, readelf, roots, loader, forbidden, executables, data):
    classified = executable_outputs(report)
    executable_roots = set(executables)
    if not executable_roots <= classified:
        raise ValueError('GNU executable profile contains unclassified/data-only outputs')
    allowed = executable_roots | set(data)
    known = origin_paths(report)
    raw = json.loads(subprocess.check_output(['nix', 'path-info', '--json', '--recursive', *roots]))
    closure = set(raw) if isinstance(raw, dict) else {p['path'] for p in raw}
    failures, files = [], {}
    for root in sorted(closure):
        if root not in allowed:
            failures.append('outside exact GNU runtime profile: ' + root)
        if root not in known:
            failures.append('unknown runtime root: ' + root)
        if root in set(forbidden) | set(report['runtimeForbiddenExecutableRoots']):
            failures.append('forbidden runtime root: ' + root)
        root_path = Path(root)
        for file in sorted(root_path.rglob('*')) if root_path.is_dir() else [root_path]:
            if file.is_symlink():
                if not within(str(file.resolve()), closure):
                    failures.append('escaping symlink: ' + str(file))
                continue
            if not file.is_file():
                continue
            with file.open('rb') as stream:
                head = stream.read(256)
            if head.startswith(b'\x7fELF'):
                if root not in executable_roots:
                    failures.append('ELF in data-only origin: ' + str(file))
                info = subprocess.check_output([readelf, '-h', '-l', '-d', str(file)], text=True)
                interpreters = re.findall(r'Requesting program interpreter: ([^\]]+)', info)
                needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]', info)
                rpaths = re.findall(r'\((?:RPATH|RUNPATH)\).*\[([^\]]*)\]', info)
                search = [entry for group in rpaths for entry in group.split(':')]
                byteorder = {1: '<', 2: '>'}.get(head[5])
                machine = struct.unpack(byteorder + 'H', head[18:20])[0] if byteorder else None
                if machine != 62:
                    failures.append('wrong GNU machine: ' + str(file))
                for interpreter in interpreters:
                    if not gnu_interpreter(interpreter, loader, executable_roots & closure):
                        failures.append('wrong GNU interpreter: ' + str(file) + ': ' + interpreter)
                for directory in search:
                    if not directory or not within(directory, executable_roots & closure):
                        failures.append('foreign GNU search path: ' + str(file) + ': ' + directory)
                # A DSO may inherit its caller's RPATH. Resolve its bare SONAMEs
                # through explicitly selected G profile directories, never all
                # incidental closure libraries. Native invocation is also probed.
                profile_search = [str(Path(loader).parent)]
                for candidate in roots:
                    for libdir in [Path(candidate) / 'lib', Path(candidate) / 'lib/gcc/x86_64-unknown-linux-gnu/16.2.0']:
                        if libdir.is_dir():
                            profile_search.append(str(libdir))
                resolved = {name: resolve_needed(name, search + profile_search, closure, executable_roots) for name in needed}
                for name, path in resolved.items():
                    if path is None:
                        failures.append('unreachable GNU dependency: ' + str(file) + ': ' + name)
                if (needed or interpreters) and all(i == loader for i in interpreters):
                    probe = subprocess.run([loader, '--list', str(file)], env={}, text=True,
                                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                    if probe.returncode:
                        failures.append('GNU loader resolution failed: ' + str(file) + ': ' + probe.stdout)
                    else:
                        actual = re.findall(r'^\s*\S+ => (/.*?) \(0x[0-9a-f]+\)$', probe.stdout, re.MULTILINE)
                        for dependency in actual:
                            if not owned_executable(dependency, executable_roots & closure):
                                failures.append('GNU loader resolved foreign dependency: ' + dependency)
                files[str(file)] = dict(kind='ELF', interpreter=interpreters, needed=resolved, rpaths=rpaths)
            elif head.startswith(b'#!'):
                line = head.split(b'\n', 1)[0][2:].decode().split()
                interpreter = line[0] if line else ''
                if not owned_executable(interpreter, executable_roots & closure):
                    failures.append('foreign/data script interpreter: ' + str(file) + ': ' + interpreter)
                files[str(file)] = dict(kind='script', interpreter=interpreter)
    return dict(schema=1, profile='private-GNU', roots=roots, loader=loader,
                closure=sorted(closure), files=files, failures=sorted(set(failures)),
                limits='Origin/search inspection plus separate operational probes; no conformance or fixed-point claim.')


if __name__ == '__main__':
    # Exact profile, never a global expanded allowlist.
    origin, profile = (json.loads(Path(p).read_text()) for p in sys.argv[1:3])
    result = audit(origin, profile['readelf'], profile['roots'], profile['loader'], profile['forbidden'], profile['executables'], profile['data'])
    print(json.dumps(result, indent=2, sort_keys=True))
    sys.exit(bool(result['failures']))
