"""GCC public metadata/dynamic paths only; never copy checkpoint provenance."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def metadata_paths(data, old, new, elf):
    # GCC's installed libtool/spec metadata also has -I/-L/-B/-R operands.
    start=0
    while True:
        pos=data.find(old,start)
        if pos<0: break
        option=(pos>=2 and data[pos-2:pos] in (b'-I',b'-L',b'-B',b'-R')
                and (pos==2 or data[pos-3] in b" \t\r\n'\"=,:("))
        end=pos+len(old)
        if ((pos and (chr(data[pos-1]).isalnum() or data[pos-1] in b'/_+-.') and not option)
                or (end<len(data) and data[end] not in b"/\x00\n\r\t '\";:),]}<>")):
            raise ValueError('non-path GCC metadata occurrence')
        start=end
    return data.replace(old,new)


def finalize(root, artifact, prefix, readelf, patchelf, inspector):
    spec=importlib.util.spec_from_file_location('gcc_elf', inspector)
    elf=importlib.util.module_from_spec(spec); spec.loader.exec_module(elf)
    root, files, groups, links=elf.tree(root)
    old,new=artifact.encode(),os.fsencode(root)
    pending=[]; planned={}
    with tempfile.TemporaryDirectory() as work:
        for i,group in enumerate(groups):
            p=files[group[0]]; data=p.read_bytes(); updated=data; dynamic=None
            if data.startswith(b'\x7fELF'):
                hits=elf.inspect(p,old,readelf)
                if any(h['section'] != '.dynstr' or not h.get('exclusiveRpath') for h in hits):
                    raise ValueError(('unsupported GCC native artifact path',group))
                if hits:
                    values={h['exclusiveRpath'] for h in hits}
                    if len(values)!=1: raise ValueError('ambiguous GCC RPATH')
                    dynamic=elf.replace_paths(values.pop().encode(),old,new).decode()
            elif old in data or prefix.encode() in data:
                # Installed scripts/pkgconfig/headers/libtool/spec metadata only.
                if not (data.startswith(b'#!') or p.suffix in ('.la','.pc','.h','.hpp','.cmake','.specs','.py','.1','.info')
                        or p.name in ('specs','g++-mapper-server')):
                    raise ValueError(('unsupported GCC text metadata',group))
                elf.text(data, group[0])
                updated=metadata_paths(data,old,new,elf)
                updated=metadata_paths(updated,prefix.encode(),new,elf)
            if updated!=data or dynamic is not None:
                staged=Path(work)/str(i); staged.write_bytes(updated)
                if dynamic is not None:
                    subprocess.run([patchelf,'--set-rpath',dynamic,str(staged)],check=True,capture_output=True)
                if old in staged.read_bytes(): raise ValueError('GCC artifact remains')
                pending.append((group,staged,p.stat()))
        for name,value in links.items():
            planned[name]=elf.replace_paths(value.encode(),old,new).decode()
            if planned[name].startswith(artifact): raise ValueError('GCC artifact link')
        def resolve(path, active=frozenset()):
            path=os.path.normpath(path)
            current=Path(path).anchor
            for part in Path(path).parts[1:]:
                current=os.path.join(current,part)
                rel=os.path.relpath(current,root)
                if rel in planned:
                    if current in active: raise ValueError('GCC symlink cycle')
                    value=planned[rel]
                    current=resolve(value if value.startswith('/') else os.path.join(os.path.dirname(current),value),active|{current})
            return current
        for name in planned:
            target=resolve(str(root/name))
            if not (target.startswith(str(root)+'/') or target.startswith('/nix/store/')):
                raise ValueError(('escaping GCC alias',name))
            if not Path(target).exists(): raise ValueError(('dangling GCC alias',name))
        # All files and links were validated; only changed data was staged.
        for group,staged,st in pending:
            p=files[group[0]]
            with p.open('r+b') as f: f.write(staged.read_bytes()); f.truncate()
            for alias in group[1:]: files[alias].unlink(); os.link(p,files[alias])
            p.chmod(st.st_mode & 0o7777); os.utime(p,ns=(st.st_atime_ns,st.st_mtime_ns))
        for name,value in planned.items():
            if value!=links[name]: (root/name).unlink(); (root/name).symlink_to(value)


if __name__=='__main__': finalize(*sys.argv[1:])
