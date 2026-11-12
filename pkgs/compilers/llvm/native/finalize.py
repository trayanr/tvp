"""Plan and validate LLVM prefix repairs before committing changed payloads.

Reuse the existing native-string and archive validators. Only changed inode
payloads are staged; the installed tree and shared helpers are never copied.
"""
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_links(root, links):
    """Resolve planned links component by component, preserving file/ semantics."""
    for name in links:
        current = root
        pending = name.split('/')
        followed = 0
        while pending:
            part = pending.pop(0)
            if part in ('', '.'):
                continue
            if part == '..':
                if current == root:
                    raise ValueError(('escaping installed symlink', name))
                current = current.parent
                continue
            current = current / part
            relative = str(current.relative_to(root))
            info = current.lstat()
            if relative in links:
                followed += 1
                if followed > 40:
                    raise ValueError(('cyclic installed symlink', name))
                target = links[relative]
                if target.startswith('/'):
                    if target != str(root) and not target.startswith(str(root) + '/'):
                        raise ValueError(('escaping absolute installed symlink', name))
                    pending = target[len(str(root)):].split('/') + pending
                    current = root
                else:
                    pending = target.split('/') + pending
                    current = current.parent
            elif pending and not stat.S_ISDIR(info.st_mode):
                raise ValueError(('non-directory installed symlink component', name))


def finalize(config, root, artifact, shared):
    config = dict(config)
    ruby = load('llvm_readonly_paths', config.pop('rubyFinalizer'))
    # Nix supplies these as separate store files, not repository siblings.
    sys.modules['elf'] = load('llvm_archive_elf', config.pop('archiveElfFinalizer'))
    container = load('llvm_archive_container', config.pop('archiveFinalizer'))
    elf = load('llvm_namespace', shared)
    root, files, groups, links = elf.tree(root)
    old, new = artifact.encode(), os.fsencode(root)
    if (old == new or len(old) != len(new)
            or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+', old)):
        raise ValueError('distinct equal-width installed store prefixes required')
    for tool in ('readelf', 'patchelf'):
        value = config[tool]
        if not value.startswith('/nix/store/') or not os.path.isfile(value) or not os.access(value, os.X_OK):
            raise ValueError(('missing explicit inspector', value))

    def member(path, data, old, new, readelf, *, relocatable=False):
        if not relocatable:
            raise ValueError('only native relocatable archive members supported')
        return ruby.object_paths(data, old, new), []

    container.readonly_paths = member
    planned_links = {
        name: os.fsdecode(ruby.replace_paths(os.fsencode(target), old, new))
        for name, target in links.items()
    }
    changes = []
    with tempfile.TemporaryDirectory(prefix='llvm-installed-payloads-') as work:
        for group in groups:
            name = group[0]
            path = files[name]
            info = path.stat()
            data = path.read_bytes()
            metadata = any(
                Path(alias).name in ('Config.pm', 'Config_heavy.pl', '.packlist', 'config.sh')
                or '/CORE/' in '/' + alias and Path(alias).suffix in ('.h', '.c', '.inc')
                for alias in group
            )
            cwd = any(Path(alias).name == 'Cwd.pm' for alias in group)
            if metadata and cwd:
                raise ValueError(('conflicting metadata/Cwd hardlink roles', group))
            if metadata or cwd:
                elf.text(data, group)
            rpath = None
            if any(Path(alias).suffix == '.a' for alias in group):
                if not all(Path(alias).suffix == '.a' for alias in group):
                    raise ValueError('mixed archive hardlink roles')
                updated = container.archive(data, old, new, config['readelf']) if old in data else data
            elif data.startswith(b'\x7fELF'):
                if len(data) >= 18 and struct.unpack_from('<H', data, 16)[0] == 1:
                    updated = ruby.object_paths(data, old, new) if old in data else data
                else:
                    hits = elf.inspect(path, old, config['readelf'])
                    updated = ruby.compiled_paths(data, hits, old, new) if old in data else data
                    result = subprocess.run(
                        [config['patchelf'], '--print-rpath', str(path)],
                        check=True, capture_output=True,
                    )
                    if result.stderr or not result.stdout.endswith(b'\n'):
                        raise ValueError(('invalid RPATH inspection', name))
                    original_rpath = result.stdout[:-1]
                    relocated = ruby.replace_paths(original_rpath, old, new)
                    for hit in hits:
                        if hit['section'] == '.dynstr' and (
                            hit.get('exclusiveRpath') is None
                            or hit['exclusiveRpath'].encode() != original_rpath
                            or old not in original_rpath
                        ):
                            raise ValueError(('unsupported dynamic prefix', name, hit))
                    if original_rpath != relocated:
                        rpath = relocated.decode()
            elif old in data:
                updated = ruby.replace_paths(elf.text(data, name), old, new)
            else:
                updated = data
            if updated == data and rpath is None:
                continue
            staged = Path(work) / str(len(changes))
            staged.write_bytes(updated)
            if rpath is not None:
                subprocess.run(
                    [config['patchelf'], '--set-rpath', rpath, str(staged)],
                    check=True, capture_output=True,
                )
                elf.inspect(staged, old, config['readelf'])
            if old in staged.read_bytes():
                raise ValueError(('artifact bytes remain in planned payload', name))
            changes.append((path, staged, info))

        # Validate every payload and the planned namespace before any tree write.
        validate_links(root, planned_links)
        for path, staged, info in changes:
            try:
                path.chmod(stat.S_IMODE(info.st_mode) | stat.S_IWUSR)
                with staged.open('rb') as source, path.open('r+b') as target:
                    shutil.copyfileobj(source, target)
                    target.truncate()
            finally:
                path.chmod(stat.S_IMODE(info.st_mode))
                os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
        for name, target in planned_links.items():
            if target != links[name]:
                path = root / name
                path.unlink()
                path.symlink_to(target)
    elf.audit(str(root), [artifact])


def main():
    finalize(json.loads(sys.argv[1]), *sys.argv[2:5])


if __name__ == '__main__':
    main()
