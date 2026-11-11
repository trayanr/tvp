"""Constrain generated Autotools scripts to explicit shell/linker searches.

No regeneration, generators or Python bindings are enabled by this operation.
Validate the complete selected set and hardlink roles before writing anything.
"""
from pathlib import Path
import os
import re
import stat
import sys


def prepare(root, shell, search):
    root = Path(root)
    if not root.is_absolute() or str(root) != str(root.resolve(strict=True)):
        raise ValueError('canonical source root required')
    if any(not stat.S_ISDIR(p.lstat().st_mode) for p in [root, *root.parents]):
        raise ValueError('source parent alias')
    if not re.fullmatch(r'/nix/store/[^/]+/bin/bash', shell):
        raise ValueError('explicit store Bash required')
    if any(not re.fullmatch(r'/nix/store/[^\s\x00\x27]+', p) for p in search):
        raise ValueError('invalid declared library search')
    paths = [root/'configure', *sorted(root.rglob('ltmain.sh'))]
    if len(paths) != 2:
        raise ValueError(('expected one generated libtool body', paths))
    changes = []
    for p in paths:
        q = p
        while q != root:
            if q.is_symlink():
                raise ValueError(('source alias', q))
            q = q.parent
        st = p.lstat()
        if not stat.S_ISREG(st.st_mode) or st.st_nlink != 1:
            raise ValueError(('nonregular/aliased source script', p))
        data = p.read_bytes()
        if b'\0' in data:
            raise ValueError('NUL in generated shell')
        # Historic generated comments use Latin-1; shell syntax is byte based.
        if p.name == 'configure':
            if not re.match(rb'#![ \t]*/bin/sh\n', data):
                raise ValueError(('unexpected configure frontend', p))
            data = b'#!'+shell.encode()+b'\n'+data.split(b'\n', 1)[1]
        elif data.startswith(b'#!'):
            if not re.match(rb'#![ \t]*(?:/bin/sh|/usr/bin/env sh)\n', data):
                raise ValueError(('unexpected libtool frontend', p))
            data = b'#!'+shell.encode()+b'\n'+data.split(b'\n', 1)[1]
        elif not data.lstrip().startswith(b'#'):
            raise ValueError('expected historic sourced libtool body')
        if p.name == 'configure':
            data = data.replace(b'/usr/bin/file', b'file')
            # Store outputs use their declared runtime paths. Installing a
            # library never refreshes a host loader cache or searches /sbin.
            finish = rb"""finish_cmds='PATH="\$PATH:/sbin" ldconfig -n $libdir'"""
            if data.count(finish) != 1:
                raise ValueError('expected Linux libtool finish command')
            data = data.replace(finish, b"finish_cmds=''")
        else:
            data, count = re.subn(rb'eval (sys_lib_search_path=).*',
                                 lambda m: m[1]+b"'"+b' '.join(s.encode() for s in search)+b"'", data)
            if count != 1:
                raise ValueError(('libtool search body changed', count))
            data = re.sub(rb'eval sys_lib_.+search_path=.*', b'', data)
        changes.append((p, st, data))
    for p, st, data in changes:
        p.write_bytes(data)
        os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))


if __name__ == '__main__':
    prepare(Path.cwd(), sys.argv[1], [f[2:] for f in os.environ.get('NIX_LDFLAGS', '').split() if f.startswith('-L')])
