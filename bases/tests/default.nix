# One suite, shared by every base. Never fork it per base: a test that exists
# only for newer substrate cannot detect drift in older substrate.
{
  pkgs,
  tvpLib,
  base,
}:
let
  selected = base.ownedBase or base;
  owned =
    if selected ? compiler && selected ? environment && !(selected ? stdenv) then
      selected
    else
      throw "TVP base tests: an owned base selection is required";
  builder = import ../../lib/builder.nix { inherit (pkgs) lib; };
  context = tvpLib.tests.forBase {
    inherit builder;
    base = owned;
    coreutils = owned.tools.coreutils;
  };
  compiler = owned.compiler;
  shared = context.mkSuite {
    package = compiler;

    tests = {
      # Not -dumpversion: it prints the full version before gcc 7 and the major
      # after it, so neither form is comparable across the catalogue.
      cc-version = {
        script = ''
          "$CC" --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
        '';
        expected = compiler.version;
      };

      binutils-version = {
        script = ''
          "${compiler.bintools}/bin/ld" --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
        '';
        expected = pkgs.lib.getVersion compiler.bintools;
      };

      libc-version = {
        script = ''
          "$CC" -x c -o libc-version - <<'C'
          #include <gnu/libc-version.h>
          #include <stdio.h>
          int main(void) { printf("glibc %s\n", gnu_get_libc_version()); }
          C
          ./libc-version
        '';
        expected = "glibc ${compiler.libc.version}";
      };

      compile = {
        script = ''
          "$CC" ${./fixtures/libc.c} -o libc
          "$READELF" -l libc | grep -F '[Requesting program interpreter: ${compiler.libc}/' >&2
          "$READELF" -l libc | grep GNU_RELRO >&2
          "$READELF" -d libc | grep -E 'BIND_NOW|FLAGS.*NOW' >&2
          ./libc
        '';
        expected = "45";
      };
      cxx = {
        script = ''
          "$CXX" ${./fixtures/cxx.cc} -o cxx
          ./cxx
        '';
        expected = "42";
      };
      response-file = {
        script = ''
          printf '%s\n' '${./fixtures/libc.c}' -o response > args
          "$CC" @args
          ./response
        '';
        expected = "45";
      };
      static = {
        script = ''
          "$CC" -static -L${compiler.libc.static or compiler.libc}/lib ${./fixtures/libc.c} -o static
          if "$READELF" -l static | grep -q INTERP; then exit 1; fi
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
