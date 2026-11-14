"""The two retained Ruby source adaptations, with exact match acceptance."""
from pathlib import Path
import sys
kind, name = sys.argv[1:]
old, new = {
    'mjit': ('transform_mjit_header.rb "$(CC) $(ARCH_FLAG)"',
             'transform_mjit_header.rb "$(CC) $(ARCH_FLAG) $(CFLAGS)"'),
    'cflags': ('\ncflagspat=\n', '\nif test -z "${ac_env_CFLAGS_set}"; then\n  { CFLAGS=; unset CFLAGS; }\nfi\n\ncflagspat=\n'),
}[kind]
p = Path(name)
s = p.read_text()
if s.count(old) != 1:
    raise ValueError((kind, 'expected one source match', s.count(old)))
p.write_text(s.replace(old, new))
