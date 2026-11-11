"""Relocate installed catalog paths and metadata after whole-tree preflight.

Equal-width prefixes retain pooled strings and static member offsets. ELF dynamic
strings use the reviewed exclusive ownership inspector and selected patchelf.
No blanket binary replacement. Archives accept only readonly path string slots in
native relocatable objects. Nothing in this helper participates in compilation.
"""
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from elf import inspect, replace_paths, text, tree


def readonly_paths(path, data, old, new, readelf, *, relocatable=False):
    changes = []
    for hit in inspect(path, old, readelf):
        if hit['section'] == '.dynstr':
            if relocatable or hit.get('exclusiveRpath') is None:
                raise ValueError('unsupported dynamic prefix')
            changes.append(('rpath', hit['exclusiveRpath']))
        elif (not hit['section'].startswith('.rodata') or not hit['readonlyAllocated']
              or not hit['prefixAtStringStart'] or hit['stringEnd'] < 0
              or not hit['string'].encode().startswith(old+b'/etc/')):
            raise ValueError(('unexpected compiled path slot', str(path), hit))
        else:
            a,b = hit['stringStart'], hit['stringEnd']
            data = data[:a]+replace_paths(data[a:b],old,new)+data[b:]
    return data, changes


def archive(data, old, new, readelf):
    if not data.startswith(b'!<arch>\n'):
        raise ValueError('expected normal ar archive')
    result = bytearray(data); pos = 8
    with tempfile.TemporaryDirectory() as tmp:
        while pos < len(data):
            header = data[pos:pos+60]
            if len(header) != 60 or header[58:] != b'`\n' or not header[48:58].strip().isdigit():
                raise ValueError('invalid ar member header')
            size = int(header[48:58]); begin = pos+60; end = begin+size
            if end > len(data):
                raise ValueError('truncated ar member')
            body = data[begin:end]
            if old in body:
                if not body.startswith(b'\x7fELF') or int.from_bytes(body[16:18], 'little') != 1:
                    raise ValueError('artifact path outside relocatable ar member')
                member = Path(tmp)/'member.o'; member.write_bytes(body)
                updated, dynamic = readonly_paths(member,body,old,new,readelf,relocatable=True)
                if len(updated) != len(body):
                    raise ValueError('archive member width changed')
                if dynamic or old in updated:
                    raise ValueError('unrelocated archive member')
                result[begin:end] = updated
            pos = end + size%2
        if pos != len(data):
            raise ValueError('invalid ar padding')
    return bytes(result)


def finalize(root, artifact, readelf, patchelf):
    root, files, groups, links = tree(root)
    old,new = artifact.encode(),os.fsencode(root)
    if (len(old) != len(new) or old == new
            or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+',old)):
        raise ValueError('distinct equal-width store prefixes required')
    for tool in (readelf, patchelf):
        if not tool.startswith('/nix/store/') or not os.path.isfile(tool) or not os.access(tool, os.X_OK):
            raise ValueError('explicit executable store inspectors required')
    changes={}; dynamics={}; planned={}
    for group in groups:
        roles = {('script' if n=='bin/xml2-config' else 'archive' if n=='lib/libxml2.a'
                  else 'metadata' if n.endswith(('.la','.pc','.cmake','.h','.m4')) else 'other') for n in group}
        if len(roles) != 1:
            raise ValueError(('conflicting hardlink roles',group))
        name=group[0]; p=files[name]; data=p.read_bytes()
        for alias in group:
            public=alias.startswith(('bin/','libexec/'))
            if public and not data.startswith((b'\x7fELF',b'#!')):
                raise ValueError(('invalid public frontend',alias))
        if data.startswith(b'#!'):
            text(data,name)
            if roles != {'script'}:
                raise ValueError(('unexpected installed script frontend', group))
        if 'script' in roles:
            text(data,name)
            if not re.match(rb'#!\s*(?:/bin/sh|/nix/store/[^/]+/bin/bash)\n',data):
                raise ValueError('unexpected xml2-config interpreter')
        if data.startswith(b'\x7fELF'):
            updated,dynamic=readonly_paths(p,data,old,new,readelf)
            if dynamic:
                if len(set(v for _,v in dynamic)) != 1:
                    raise ValueError('ambiguous dynamic path')
                raw=dynamic[0][1]; value=replace_paths(raw.encode(),old,new).decode()
                for entry in value.split(':'):
                    if not (re.fullmatch(r'/nix/store/[^:]+',entry) or re.fullmatch(r'\$ORIGIN(?:/[A-Za-z0-9_.+-]+)*',entry)) or '..' in entry.split('/'):
                        raise ValueError(('invalid loader path',entry))
                dynamics[name]=value
            changes[name]=updated
        elif name=='lib/libxml2.a':
            changes[name]=archive(data,old,new,readelf)
        elif old in data:
            changes[name]=replace_paths(text(data,name),old,new)
    for name,target in links.items():
        target=replace_paths(target.encode(),old,new).decode()
        if target.startswith('/'):
            if not target.startswith(str(root)+'/'):
                raise ValueError(('outside symlink',name))
            target=os.path.relpath(target,(root/name).parent)
        planned[name]=target
    def resolve(name,active=frozenset()):
        if name in active:
            raise ValueError('symlink cycle')
        parts=list(Path(name).parent.parts)+list(Path(planned[name]).parts); out=[]
        for part in parts:
            if part=='..':
                if not out: raise ValueError('escaping symlink')
                out.pop()
            elif part!='.':
                out.append(part); partial='/'.join(out)
                if partial in planned: out=list(resolve(partial,active|{name}).parts)
        result=Path(*out)
        if not (root/result).exists(): raise ValueError('dangling planned symlink')
        return result
    for name in planned:
        target=resolve(name)
        if name.startswith(('bin/','libexec/')) and target.as_posix() not in files:
            raise ValueError('invalid frontend alias')
    # No final-tree mutation occurred above. Preserve internal alias groups.
    for group in groups:
        name=group[0]
        if name not in changes: continue
        path=files[name]; st=path.stat(); mode=stat.S_IMODE(st.st_mode)
        with path.open('r+b') as f: f.write(changes[name]); f.truncate()
        if name in dynamics:
            result=subprocess.run([patchelf,'--set-rpath',dynamics[name],str(path)],capture_output=True,check=True)
            if result.stderr: raise ValueError(('patchelf diagnostics',result.stderr))
        for alias in group[1:]: files[alias].unlink(); os.link(path,files[alias])
        path.chmod(mode); os.utime(path,ns=(st.st_atime_ns,st.st_mtime_ns))
    for name,target in planned.items():
        if target!=links[name]: (root/name).unlink(); (root/name).symlink_to(target)
    _,files,_,links=tree(root)
    if any(old in p.read_bytes() for p in files.values()) or any(artifact in v for v in links.values()):
        raise ValueError('artifact reference remains')


if __name__=='__main__':
    finalize(*sys.argv[1:])
