# Full native bootstrap source preparation: target-library configuration remains
# upstream. This procedure is independent of the compiler-only checkpoint.
{
  lib,
  base,
  bash,
  coreutils,
  src,
  version,
  layoutPatch,
  patches,
  libc,
  python,
  gnutar,
  xz,
  patch,
}:
final: {
  pname = "source-full-gcc-source";
  inherit version;
  inherit
    base
    bash
    coreutils
    src
    ;
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
        patch -Np1 -i ${layoutPatch}
        ${lib.concatMapStringsSep "\n" (p: "patch -Np1 -i ${p}") patches}
        ${python}/bin/python3 -B - "$out" <<'PY'
        import pathlib, re, sys
        root = pathlib.Path(sys.argv[1])
        p = root/'gcc/config/i386/linux64.h'
        text, n = re.subn(r'^(#define GLIBC_DYNAMIC_LINKER[A-Z0-9]* )"[^"]*"',
            r'\1"${libc}/lib/ld-linux-x86-64.so.2"', p.read_text(), flags=re.M)
        assert n == 3
        p.write_text(text)
        for p in root.rglob('*'):
            if not p.is_file() or p.is_symlink(): continue
            with p.open('rb') as f: head = f.read(128).split(b'\n')[0]
            if head.startswith((b'#!/bin/sh', b'#! /bin/sh', b'#!/bin/bash')):
                p.write_bytes(b'#!${bash}/bin/bash\n' + p.read_bytes().split(b'\n', 1)[1])
        PY
        # Release-generated lexer is valid; copying/patching must not regenerate it.
        touch gcc/gengtype-lex.cc
      '';
    }
  ];
}
