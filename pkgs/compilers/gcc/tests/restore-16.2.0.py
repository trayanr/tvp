"""Validation-only private restoration. Explicit production policy input."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tarfile


def restore(sidecar, workspace, policy):
    module=importlib.util.spec_from_file_location('gcc_checkpoint_policy',policy)
    checkpoint=importlib.util.module_from_spec(module); module.loader.exec_module(checkpoint)
    selected=checkpoint.selected
    layout = json.loads((sidecar/'layout.json').read_text()); original = Path(layout['root'])
    # The runner already creates its private workspace. Reuse that exact root
    # when it matches production: generated scripts and binaries contain paths
    # beyond the small generated-text rebasing allowlist below.
    same_workspace = original == workspace
    target = workspace if same_workspace else (
        original if original.is_relative_to('/build') and not original.exists()
        else workspace/'checkpoint')
    if target.resolve() != target or (target.exists() and not (
            same_workspace and target.is_dir())):
        raise ValueError('nonprivate restore destination')
    if same_workspace and any(os.path.lexists(target/top) for top in ('source', 'build')):
        raise ValueError('restore namespace already occupied')
    if os.path.lexists(workspace/'tree-path'):
        raise ValueError('restore receipt already exists')
    with tarfile.open(sidecar/'tree.tar') as archive:
        members = archive.getmembers(); names = {m.name for m in members}
        if len(names) != len(members) or names != set(layout['members']) or names != set(layout['mtimeNs']):
            raise ValueError('checkpoint inventory mismatch')
        symlinks = {m.name for m in members if m.issym()}
        for m in members:
            path = Path(m.name)
            if path.is_absolute() or '..' in path.parts or not selected(m.name):
                raise ValueError('unsafe checkpoint member')
            if any(str(p) in symlinks for p in path.parents):
                raise ValueError('write through checkpoint symlink')
            if m.issym() or m.islnk():
                link = os.path.normpath(str(path.parent/m.linkname) if m.issym() else m.linkname)
                if os.path.isabs(m.linkname) or link.startswith('../') or link not in names:
                    raise ValueError('external checkpoint link')
            elif not (m.isfile() or m.isdir()):
                raise ValueError('special checkpoint member')
        target.mkdir(exist_ok=same_workspace)
        archive.extractall(target, filter='fully_trusted')
    # Touch only archive members, not unrelated runner-owned workspace files.
    for name in names:
        p = target/name
        if not p.is_symlink(): p.chmod(p.stat().st_mode | 0o200)
    # Rebase generated text only. Native products relocate through their own
    # executable-relative lookup; original A runtime libraries remain immutable.
    if target != original:
        for p in (target/'build').rglob('*'):
            if p.is_file() and not p.is_symlink() and (p.name in ('Makefile','config.status','libtool','site.exp') or p.suffix == '.d'):
                data=p.read_bytes()
                if str(original).encode() in data:
                    if b'\0' in data: raise ValueError('binary checkpoint metadata')
                    p.write_bytes(data.replace(str(original).encode(), str(target).encode()))
    for name in sorted(names, key=lambda n:n.count('/'), reverse=True):
        stamp=layout['mtimeNs'][name]; os.utime(target/name, ns=(stamp,stamp), follow_symlinks=False)
    (workspace/'tree-path').write_text(str(target)+'\n')


if __name__=='__main__': restore(*map(Path,sys.argv[1:]))
