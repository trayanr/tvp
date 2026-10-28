# One suite, shared by every base. Never fork it per base: a test that exists
# only for newer substrate cannot detect drift in older substrate.
{
  pkgs,
  tvpLib,
  base,
}:
let
  shared = tvpLib.bases.mkBaseSuite {
    inherit base;

    tests = {
      # Not -dumpversion: it prints the full version before gcc 7 and the major
      # after it, so neither form is comparable across the catalogue.
      cc-version = {
        script = "cc --version | head -1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'";
        expected = base.cc;
      };

      binutils-version = {
        script = ''
          ${base.stdenv.cc.bintools}/bin/ld --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
        '';
        expected = base.binutils;
      };

      libc-version = {
        script = ''
          ${base.stdenv.cc.libc.bin}/bin/getconf GNU_LIBC_VERSION
        '';
        expected = "glibc ${base.libc}";
      };

      compile = {
        script = ''
          cc ${./fixtures/libc.c} -o libc
          readelf -l libc | grep -F '${base.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2' >&2
          readelf -l libc | grep GNU_RELRO >&2
          readelf -d libc | grep -E 'BIND_NOW|FLAGS.*NOW' >&2
          ./libc
        '';
        expected = "45";
      };
      cxx = {
        script = ''
          c++ ${./fixtures/cxx.cc} -o cxx
          ./cxx
        '';
        expected = "42";
      };
      response-file = {
        script = ''
          printf '%s\n' '${./fixtures/libc.c}' -o response > args
          cc @args
          ./response
        '';
        expected = "45";
      };
      static = {
        script = ''
          cc -static -L${base.stdenv.cc.libc.static or base.stdenv.cc.libc}/lib ${./fixtures/libc.c} -o static
          if readelf -l static | grep -q INTERP; then exit 1; fi
          ./static
        '';
        expected = "45";
      };

      # One representative binary per floor package. `command -v` alone would pass
      # for a path that is not runnable.
      floor = {
        script = ''
          for t in cp find diff sed grep awk tar gzip bzip2 make bash patch xz file; do
            $t --version > /dev/null 2>&1 || { echo "not runnable: $t"; exit 0; }
          done
          echo ok
        '';
        expected = "ok";
      };
    };
  };
in
tvpLib.packages.merge {
  inherit shared;
  ownership = if base ? ownership then import ./ownership.nix { inherit pkgs tvpLib base; } else { };
  extra = if base ? mkExtraTests then base.mkExtraTests base else { };
}
