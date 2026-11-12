"""Reserve Gawk 3's exact io.c shell literals; the runtime provider is bound in F."""
from pathlib import Path
import os
import sys

p = Path('io.c')
if p.is_symlink() or not p.is_file() or p.stat().st_nlink != 1:
    raise ValueError('regular private io.c required')
data = p.read_bytes()
literal = b'"/bin/sh"'
slot = b'"/bin/sh\\0TVP_ORDINARY_SHELL_' + b'X' * 238 + b'"'
before = slot if len(sys.argv) == 3 else literal
if b'\0' in data or data.count(before) != int(sys.argv[1]):
    raise ValueError('unexpected Gawk 3 shell literal count')
if len(sys.argv) == 3:
    # Only the independent upstream tree is bound before compilation. A keeps
    # the source-reserved slot and F selects its installed runtime provider.
    shell = sys.argv[2]
    if not shell.startswith('/nix/store/') or not shell.endswith('/bin/bash') or any(c in shell for c in '\n\r\0"\\'):
        raise ValueError('explicit test-shell store path required')
    after = b'"' + shell.encode() + b'"'
else:
    after = slot
st = p.stat()
p.write_bytes(data.replace(before, after))
os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
