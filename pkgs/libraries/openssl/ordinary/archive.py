"""Equal-width self paths in GNU ar's ELF64 relocatable members only.

No addresses, relocation records, offsets, symbols or archive indices move.
This is the ET_REL operation missing from the retained runtime ELF inspector.
"""
import struct
import subprocess
import tempfile
from pathlib import Path


def relocate(data, old, new, readelf, replace):
    if not data.startswith(b'!<arch>\n'):
        raise ValueError('expected ordinary ar archive')
    cursor, edits = 8, []
    while cursor < len(data):
        if cursor + 60 > len(data) or data[cursor+58:cursor+60] != b'`\n':
            raise ValueError('invalid ar member header')
        try:
            size = int(data[cursor+48:cursor+58].decode('ascii').strip())
        except ValueError:
            raise ValueError('invalid ar member size') from None
        begin, end = cursor+60, cursor+60+size
        if size < 0 or end > len(data):
            raise ValueError('truncated ar member')
        member = data[begin:end]
        if old in member:
            if len(member)<64 or member[:7] != b'\x7fELF\x02\x01\x01':
                raise ValueError('self path in unsupported ar member')
            kind,machine,version=struct.unpack_from('<HHI',member,16)
            if (kind,machine,version)!=(1,62,1):
                raise ValueError('expected x86_64 ET_REL archive member')
            with tempfile.TemporaryDirectory(prefix='openssl-ar-inspect-') as td:
                p=Path(td)/'member.o'; p.write_bytes(member)
                probe=subprocess.run([readelf,'-W','-h','-S','-r',str(p)],check=True,capture_output=True)
                if probe.stderr:
                    raise ValueError('ar member inspector diagnostics')
            shoff=struct.unpack_from('<Q',member,40)[0]
            ehsize,phsize,phnum,shsize,shnum,names=struct.unpack_from('<HHHHHH',member,52)
            if ehsize!=64 or phnum or shsize!=64 or not shnum or not 0<names<shnum or shoff+shsize*shnum>len(member):
                raise ValueError('unsupported relocatable section layout')
            sections=[struct.unpack_from('<IIQQQQIIQQ',member,shoff+64*i) for i in range(shnum)]
            table=sections[names]
            if table[1]!=3 or table[4]+table[5]>len(member):
                raise ValueError('bad section string table')
            strings=member[table[4]:table[4]+table[5]]
            for s in sections:
                if s[1]!=8 and s[4]+s[5]>len(member):
                    raise ValueError('truncated section')
            pos=0
            while True:
                hit=member.find(old,pos)
                if hit<0: break
                owners=[s for s in sections if s[1]!=8 and s[4]<=hit and hit+len(old)<=s[4]+s[5]]
                if len(owners)!=1:
                    raise ValueError('archive self path lacks unique owner')
                s=owners[0]
                noff=s[0]
                if noff>=len(strings) or b'\0' not in strings[noff:]:
                    raise ValueError('invalid section name')
                name=strings[noff:strings.index(b'\0',noff)]
                if not name.startswith(b'.rodata') or s[1]!=1 or s[2]&7!=2:
                    raise ValueError(('unsupported archive self-path section',name))
                start=max(s[4],member.rfind(b'\0',s[4],hit)+1)
                stop=member.find(b'\0',hit,s[4]+s[5])
                if stop<0:
                    raise ValueError('unterminated archive self string')
                prefix=member[start:hit]
                if prefix not in (b'',b'OPENSSLDIR: "',b'ENGINESDIR: "',b'MODULESDIR: "'):
                    raise ValueError(('unexpected archive self string',prefix))
                value=replace(member[start:stop],old,new)
                if len(value)!=stop-start:
                    raise ValueError('archive relocation changed width')
                member=member[:start]+value+member[stop:]
                pos=hit+len(old)
            edits.append((begin,end,member))
        cursor=end+(size%2)
    if cursor!=len(data):
        raise ValueError('invalid archive padding')
    for begin,end,member in edits:
        data=data[:begin]+member+data[end:]
    return data
