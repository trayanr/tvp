"""LLVM installed prefix transport using the reviewed Ruby/Perl ELF rules.

Reuse libxml2's width-preserving ar container parser and Ruby's native ET_REL
readonly-path guard for installed development archives. No bitcode, serialized
or signed payload rewrite: an unsupported prefix-bearing member fails closed.
Raw CMake provenance is removed by the caller before this operation.
"""
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    config = json.loads(sys.argv[1])
    root, artifact, shared = sys.argv[2:5]
    ruby = load('llvm_readonly_paths', config.pop('rubyFinalizer'))
    # libxml2's existing container parser imports its own reviewed ELF module.
    container_path = Path(config.pop('archiveFinalizer'))
    sys.path.insert(0, str(container_path.parent))
    container = load('llvm_archive_container', container_path)
    elf = load('llvm_namespace', shared)
    old, new = artifact.encode(), os.fsencode(root)
    if old == new or len(old) != len(new):
        raise ValueError('distinct equal-width installed prefixes required')

    def member(path, data, old, new, readelf, *, relocatable=False):
        if not relocatable:
            raise ValueError('only native relocatable archive members supported')
        return ruby.object_paths(data, old, new), []

    container.readonly_paths = member
    _, files, groups, _ = elf.tree(root)
    archives = []
    # Validate and stage every selected archive before changing the output.
    with tempfile.TemporaryDirectory(prefix='llvm-installed-archives-') as work:
        for group in groups:
            if not any(Path(n).suffix == '.a' for n in group):
                continue
            if not all(Path(n).suffix == '.a' for n in group):
                raise ValueError('mixed archive hardlink roles')
            path = files[group[0]]
            data = path.read_bytes()
            if old not in data:
                continue
            updated = container.archive(data, old, new, config['readelf'])
            if old in updated or len(updated) != len(data):
                raise ValueError('unrelocated archive or changed container width')
            staged = Path(work) / str(len(archives))
            staged.write_bytes(updated)
            archives.append((group, staged, path.stat()))
        try:
            # Keep pathnames and alias inodes while the existing dynamic ELF /
            # text finalizer runs. Restore all development bytes on failure too.
            for group, _, _ in archives:
                files[group[0]].write_bytes(b'')
            sys.argv = [sys.argv[0], json.dumps(config), root, artifact, shared]
            ruby.main()
        finally:
            for group, staged, info in archives:
                path = files[group[0]]
                path.write_bytes(staged.read_bytes())
                path.chmod(stat.S_IMODE(info.st_mode))
                os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
                # The shared namespace pass keeps empty aliases intact.
                if any(not os.path.samefile(path, files[n]) for n in group):
                    raise ValueError('archive aliases changed during finalization')
        elf.audit(root, [artifact])


if __name__ == '__main__':
    main()
