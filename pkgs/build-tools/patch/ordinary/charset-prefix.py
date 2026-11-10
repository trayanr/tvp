"""Keep gnulib's LIBDIR literal contiguous for installed-prefix relocation.

GCC otherwise vectorizes the localcharset memcpy into truncated constant chunks.
The opaque getter preserves the exact build prefix and upstream runtime semantics.
"""
from pathlib import Path
p=Path('lib/localcharset.c')
assert not p.is_symlink() and p.resolve(strict=True).is_relative_to(Path.cwd().resolve())
assert p.stat().st_nlink==1
s=p.read_text()
anchor='#ifndef LIBDIR\n# include "configmake.h"\n#endif'
assert s.count(anchor)==1 and 'LIBDIR' in s
s=s.replace(anchor, anchor + '\n' + '''
static __attribute__((noinline, noipa)) const char *
tvp_charset_libdir (void)
{
  return LIBDIR;
}
#undef LIBDIR
#define LIBDIR tvp_charset_libdir()
''',1)
p.write_text(s)
