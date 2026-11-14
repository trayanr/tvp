"""Restore/rebase only private validation trees. Never a production input."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tarfile


def restore(sidecar, workspace):
    layout = json.loads((sidecar / 'layout.json').read_text())
    original = Path(layout['source'])
    # Preserve the sandbox absolute layout if it is private and available. Never
    # restore into the store, an existing tree, or a parent containing a symlink.
    target = original
    if not original.is_relative_to('/build') or original.exists():
        target = workspace / 'source'
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.parent.resolve() != target.parent:
            raise ValueError('symlink restore parent')
        target.mkdir()
    except PermissionError:
        target = workspace / 'source'
        target.mkdir()
    with tarfile.open(sidecar / 'tree.tar') as archive:
        members = archive.getmembers()
        names = {m.name for m in members}
        if len(names) != len(members) or names != set(layout['members']):
            raise ValueError('archive/layout disagreement')
        links = {m.name for m in members if m.issym()}
        for m in members:
            p = Path(m.name)
            if p.is_absolute() or '..' in p.parts or not (m.isfile() or m.isdir() or m.issym()):
                raise ValueError('unsafe archive member')
            if any(parent.as_posix() in links for parent in p.parents):
                raise ValueError('archive writes through link')
            if m.issym():
                link = Path(m.linkname)
                resolved = (target / p.parent / link).resolve()
                if link.is_absolute() or not resolved.is_relative_to(target):
                    raise ValueError('external archive link')
        archive.extractall(target, filter='fully_trusted')
    namespace(target)
    for parent, dirs, files in os.walk(target, followlinks=False):
        for p in [Path(parent)] + [Path(parent) / x for x in files]:
            if not p.is_symlink():
                p.chmod(p.stat().st_mode | stat.S_IWUSR)
    if target != original:
        rebase(target, str(original), str(target))
    # PAX float timestamps alone can round nanoseconds. Restore the exact
    # lstat times from the checkpoint after private writes/rebasing.
    if set(layout['metadata']) != set(layout['members']):
        raise ValueError('incomplete member metadata')
    for name in sorted(layout['metadata'], key=lambda x: x.count('/'), reverse=True):
        p = target / name
        stamp = layout['metadata'][name]['mtimeNs']
        os.utime(p, ns=(stamp, stamp), follow_symlinks=False)
    (workspace / 'tree-path').write_text(str(target) + '\n')
    (workspace / 'source-date-epoch').write_text(layout['sourceDateEpoch'] + '\n')
    (workspace / 'production-prefix').write_text(layout['prefix'] + '\n')
    shutil.copyfile(sidecar / 'layout.json', workspace / 'restored-layout.json')


def rebase(root, old, new):
    # Only identified generated build metadata. Never rewrite source, binaries or
    # the installed/configured prefix. Object debug paths may remain historical.
    for p in root.rglob('*'):
        if p.is_file() and not p.is_symlink() and (
            p.name in ('Makefile', 'config.status', 'libtool', 'auto.def', 'tclConfig.sh', '.tcl-env.sh', 'testfixture')
            or p.suffix in ('.la', '.lai', '.lo', '.d') or '.deps' in p.parts):
            b = p.read_bytes()
            # Old libtool's generated launcher is shell metadata. Modern
            # testfixture is an ELF binary: never rewrite its debug/string data.
            if p.name == 'testfixture' and b'\0' in b:
                continue
            if old.encode() in b:
                if b'\0' in b:
                    raise ValueError(f'binary build metadata: {p}')
                s = p.stat()
                p.write_bytes(b.replace(old.encode(), new.encode()))
                os.utime(p, ns=(s.st_atime_ns, s.st_mtime_ns))


if __name__ == '__main__':
    module = importlib.util.spec_from_file_location('production_checkpoint', sys.argv[3])
    checkpoint = importlib.util.module_from_spec(module)
    module.loader.exec_module(checkpoint)
    namespace = checkpoint.namespace
    restore(Path(sys.argv[1]), Path(sys.argv[2]))
