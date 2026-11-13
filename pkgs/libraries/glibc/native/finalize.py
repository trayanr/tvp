"""glibc-specific equal-width path policy, over the existing ELF inspector.

Preflight both namespaces and every byte owner before writes; stage only changed
files. Loader paths keep compiled lengths. No arbitrary binary substitution and
no source/localedata/localedef dependency. Static archive offsets are unchanged.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import tempfile

# Source-defined install defaults (not unrelated upstream /etc or /var defaults).
DEFAULTS = {b'', b'/lib', b'/lib/', b'/lib64', b'/lib64/',
    b'/lib/ld-linux-x86-64.so.2', b'/etc', b'/etc/ld.so.cache',
    b'/etc/ld.so.conf', b'/etc/nscd.conf', b'/etc/ld.so.preload', b'/lib/gconv', b'/lib/gconv/',
    b'/lib/locale', b'/lib/locale/', b'/share/locale', b'/share/i18n',
    b'/share/zoneinfo', b'/libexec/getconf', b'/libexec/getconf/',
    b'/lib/locale/locale-archive', b'/lib/gconv/gconv-modules',
    b'/lib/gconv/gconv-modules.cache', b'/lib/gconv/gconv-modules.d',
    b'/share/i18n/locales', b'/share/i18n/charmaps'}
GETCONF = ('POSIX_V6_LP64_OFF64', 'XBS5_LP64_OFF64', 'POSIX_V7_LP64_OFF64')


def slot(value, old, new, role):
    if len(old)!=len(new) or old==new: raise ValueError('equal-width distinct glibc roots required')
    # dl-usage.c's single help literal contains both LD_SO_CACHE and RTLD.
    # Match its complete normalized content, not just two familiar markers.
    # This hash is from glibc-2.39/elf/dl-usage.c, with only those macros expanded.
    if value.count(old)==2 and hashlib.sha256(value.replace(old,b'@ROOT@')).hexdigest() == '9f5f22aeccd81bb311e0a4f35fc31539d412e93deefe784497577eef2c886875':
        return value.replace(old,new)
    if not value.startswith(old) or value[len(old):] not in DEFAULTS:
        raise ValueError(('unknown glibc constant',role,value))
    return new+value[len(old):]


def readonly_constants(data, old, new):
    # The shared inspector has validated the ELF layout before its diagnostic
    # string decoding failed. Readonly constants need not follow another NUL.
    shoff=struct.unpack_from('<Q',data,40)[0]
    shsize,shnum,names=struct.unpack_from('<HHH',data,58)
    records=[struct.unpack_from('<IIQQQQIIQQ',data,shoff+i*shsize) for i in range(shnum)]
    table=records[names]; strings=data[table[4]:table[4]+table[5]]
    sections=[(strings[r[0]:strings.index(b'\0',r[0])].decode('ascii'),r) for r in records]
    result=data; pos=0
    while True:
        pos=data.find(old,pos)
        if pos<0: break
        owners=[(name,r) for name,r in sections if r[1]!=8 and r[4]<=pos and pos+len(old)<=r[4]+r[5]]
        if len(owners)!=1: raise ValueError('ambiguous glibc constant owner')
        name,section=owners[0]
        if name.startswith('.rodata') and section[2]&2 and not section[2]&5:
            begin=max(section[4],data.rfind(b'\0',section[4],pos)+1)
            end=data.find(b'\0',pos,section[4]+section[5])
            if end<0: raise ValueError('unterminated glibc constant')
            try: value=slot(data[begin:end],old,new,name)
            except ValueError:
                begin=pos
                value=slot(data[begin:end],old,new,name)
            result=result[:begin]+value+result[end:]
        pos+=len(old)
    return result


def native(path, data, mapping, elf, readelf):
    result=data
    for old,new in mapping:
        try: hits=elf.inspect(path,old,readelf)
        except UnicodeDecodeError:
            changed=readonly_constants(result,old,new)
            if changed==result: raise
            result=changed
            # Inspect every remaining occurrence with the unchanged shared
            # policy; dynamic strings and PT_INTERP keep their normal checks.
            with tempfile.TemporaryDirectory() as directory:
                view=Path(directory)/'native'; view.write_bytes(result)
                hits=elf.inspect(view,old,readelf)
        for h in hits:
            begin,end=h['stringStart'],h['stringEnd']
            if h['section']=='.interp':
                phoff=struct.unpack_from('<Q',data,32)[0]
                phsize,phnum=struct.unpack_from('<HH',data,54)
                if (data[16:18]==b'\x01\x00' or phsize!=56 or not phnum
                        or phoff+phnum*phsize>len(data)):
                    raise ValueError('invalid glibc interpreter program table')
                owners=[struct.unpack_from('<IIQQQQQQ',data,phoff+i*56)
                        for i in range(phnum)]
                if [(p[2],p[5]) for p in owners if p[0]==3] != [(begin,end+1-begin)]:
                    raise ValueError('glibc interpreter section/program disagreement')
                if data[begin:end] != old+b'/lib/ld-linux-x86-64.so.2':
                    raise ValueError('unknown glibc PT_INTERP')
            elif h['section']=='.dynstr':
                if not h.get('exclusiveRpath'): raise ValueError('unknown glibc dynamic path')
                # Equal-width exclusive RPATH bytes preserve all offsets.
                value=elf.replace_paths(result[begin:end],old,new)
                result=result[:begin]+value+result[end:]
                continue
            elif not (h['section'].startswith('.rodata') and h['readonlyAllocated'] and end>=0):
                raise ValueError(('unknown glibc path owner',str(path),h))
            value=slot(data[begin:end],old,new,h['section'])
            result=result[:begin]+value+result[end:]
    return result


def archive(data, mapping, elf, readelf, scratch):
    if not data.startswith(b'!<arch>\n'): raise ValueError('normal ar required')
    result=bytearray(data); pos=8
    while pos<len(data):
        header=data[pos:pos+60]
        if len(header)!=60 or header[58:]!=b'`\n' or not header[48:58].strip().isdigit():
            raise ValueError('malformed glibc ar member')
        size=int(header[48:58]); begin=pos+60; end=begin+size
        if end>len(data): raise ValueError('truncated glibc ar member')
        body=data[begin:end]
        if any(old in body for old,new in mapping):
            if not body.startswith(b'\x7fELF') or body[16:18]!=b'\x01\x00':
                raise ValueError('path outside native static member')
            member=scratch/'member.o'; member.write_bytes(body)
            result[begin:end]=native(member,body,mapping,elf,readelf)
        pos=end+size%2
    if pos!=len(data): raise ValueError('invalid ar padding')
    return bytes(result)


def finalize(config, inspector):
    module=importlib.util.spec_from_file_location('glibc_elf',inspector)
    elf=importlib.util.module_from_spec(module); module.loader.exec_module(elf)
    roots=config['roots']; artifacts=config['artifacts']
    if set(roots)!= {'out','bin'} or set(artifacts)!=set(roots):
        raise ValueError('complete out/bin map required')
    mapping=[]; trees={}
    for name in ('out','bin'):
        old,new=artifacts[name].encode(),roots[name].encode()
        if len(old)!=len(new) or old==new or not re.fullmatch(rb'/nix/store/[a-z0-9]{32}-[^/]+',old):
            raise ValueError('invalid glibc transport roots')
        mapping.append((old,new)); trees[name]=elf.tree(roots[name])
    planned_links=[]; pending=[]; removals=[]
    cache=Path(roots['out'])/'etc/ld.so.cache'
    if (cache.parent.is_symlink() or (cache.parent.exists() and not cache.parent.is_dir()) or cache.is_symlink()
            or (cache.exists() and not cache.is_file())):
        raise ValueError('owned glibc cache location required')
    def transport(value):
        for old,new in mapping: value=elf.replace_paths(value,old,new)
        return value
    # Build a virtual namespace spanning both outputs; every link is resolved
    # against the planned namespace, never through an old artifact link.
    linkmap={}
    for root,files,groups,links in trees.values():
        for name,value in links.items(): linkmap[str(root/name)]=transport(value.encode()).decode()
    def resolve(path, active=frozenset()):
        path=os.path.normpath(path)
        parts=Path(path).parts; current=parts[0]
        for part in parts[1:]:
            current=os.path.join(current,part)
            if current in linkmap:
                if current in active: raise ValueError('glibc symlink cycle')
                value=linkmap[current]
                current=resolve(value if value.startswith('/') else os.path.join(os.path.dirname(current),value),active|{current})
        return current
    for path,value in linkmap.items():
        destination=resolve(path)
        if not any(destination==r or destination.startswith(r+'/') for r in roots.values()):
            if not destination.startswith(config['linuxHeaders']+'/include/'):
                raise ValueError(('unsupported glibc external alias',path,destination))
        if not Path(destination).exists(): raise ValueError(('dangling planned glibc link',path))
        planned_links.append((Path(path),value))
    aliases=[Path(roots['out'])/'libexec/getconf'/n for n in GETCONF]
    getconf=Path(roots['bin'])/'bin/getconf'
    if not getconf.is_file() or any(not p.is_file() or p.is_symlink() for p in aliases):
        raise ValueError('missing getconf hardlink interface')
    with tempfile.TemporaryDirectory() as temporary:
        scratch=Path(temporary)
        for root,files,groups,links in trees.values():
            for group in groups:
                p=files[group[0]]; data=p.read_bytes(); updated=data
                if cache in [files[n] for n in group]:
                    if len(group)!=1 or not data.startswith(b'glibc-ld.so.cache1.1'):
                        raise ValueError('unsupported/shared glibc cache')
                    # ldconfig regenerates this binary from final library paths.
                    removals.append(cache)
                    continue
                if any(old in data for old,new in mapping):
                    if data.startswith(b'\x7fELF'):
                        updated=native(p,data,mapping,elf,config['readelf'])
                    elif data.startswith(b'!<arch>\n'):
                        updated=archive(data,mapping,elf,config['readelf'],scratch)
                    else:
                        elf.text(data,str(p))
                        if not (p.suffix in ('.h','.so','.a','.pc','.la','.conf') or data.startswith(b'#!') or '/share/' in str(p)):
                            raise ValueError(('unknown glibc text role',str(p)))
                        updated=transport(data)
                if any(old in updated for old,new in mapping): raise ValueError('glibc artifact remains')
                if updated!=data:
                    staged=scratch/('change-'+str(len(pending))); staged.write_bytes(updated)
                    pending.append(([files[n] for n in group],staged,p.stat()))
        # Whole payload and namespace now validated. Same-width edits include
        # known self PT_INTERP; do not shrink the loader or mutate its RPATH.
        for group,staged,info in pending:
            p=group[0]
            with p.open('r+b') as stream: stream.write(staged.read_bytes()); stream.truncate()
            for alias in group[1:]: alias.unlink(); os.link(p,alias)
            p.chmod(stat.S_IMODE(info.st_mode)); os.utime(p,ns=(info.st_atime_ns,info.st_mtime_ns))
        for path,value in planned_links:
            if os.readlink(path)!=value: path.unlink(); path.symlink_to(value)
        for alias in aliases: alias.unlink(); os.link(getconf,alias)
        for path in removals: path.unlink()


if __name__=='__main__': finalize(json.loads(sys.argv[1]),sys.argv[2])
