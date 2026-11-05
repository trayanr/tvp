{
  tvp,
  lib,
  base,
  bash,
  coreutils,
  profile,
  python,
  binutils,
  gnumake,
  tools,
  sources,
  gnutar,
  xz,
  patch,
}:
final: {
  pname = "source-native-gcc-source";
  version = "16.2.0";
  src = sources.gcc;
  inherit base bash coreutils;
  plan = [
    {
      name = "gcc-source.prepare";
      tools = [
        gnutar
        xz
        patch
        python
      ];
      run = ''
        mkdir -p "$out"
        tar xf ${final.src} --directory="$out" --strip-components=1
        cd "$out"
        patch -Np1 -i ${sources.layout}
        patch -Np1 -i ${../../gcc/configure-skip-target-libs-hooks.patch}
        ${python}/bin/python3 -B - "$out" <<'PY'
        import pathlib, sys, re
        root = pathlib.Path(sys.argv[1])
        p = root/'gcc/gcc.cc'
        text = p.read_text()
        old = '#define STANDARD_STARTFILE_PREFIX_2 "/usr/lib/"'
        assert old in text
        p.write_text(text.replace(old, '#define STANDARD_STARTFILE_PREFIX_2 ""'))
        for name in ['gcc/config/i386/linux64.h', 'gcc/config/linux.h']:
            p = root/name
            text, count = re.subn(r'^(#define GLIBC_DYNAMIC_LINKER[A-Z0-9]* )"[^"]*"',
                r'\1"${profile.libc}/lib/ld-linux-x86-64.so.2"', p.read_text(), flags=re.M)
            assert count == (3 if name.endswith('linux64.h') else 0)
            p.write_text(text)
        for p in root.rglob('*'):
            if not p.is_file() or p.is_symlink(): continue
            with p.open('rb') as f: head = f.read(128).split(b'\n')[0]
            if head.startswith((b'#!/bin/sh', b'#! /bin/sh', b'#!/bin/bash')):
                data = p.read_bytes().split(b'\n', 1)
                p.write_bytes(b'#!${bash}/bin/bash\n' + data[1])
        PY
        touch gcc/gengtype-lex.cc
      '';
    }
  ];
}
