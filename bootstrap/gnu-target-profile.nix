# Opt-in capability-libc runtime ladder. Existing bootstrap endpoints stay exact.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  adapter = import ./adapter.nix { system = "x86_64-linux"; };
  scope = b // {
    inherit (adapter) lib;
    buildPlatform.config = "x86_64-unknown-linux-musl";
    fetchurl =
      attrs:
      import <nix/fetchurl.nix> (
        attrs
        // {
          url = builtins.replaceStrings [ "mirror://gnu/" ] [ "https://ftpmirror.gnu.org/" ] attrs.url;
        }
      );
  };
  call =
    file: args:
    let
      f = import file;
    in
    f (builtins.intersectAttrs (builtins.functionArgs f) scope // args);
  platform = {
    config = "x86_64-unknown-linux-gnu";
    isMusl = false;
  };
  common = {
    coreutils = b.coreutils-musl;
    gnumake = b.gnumake-musl;
    gnutar = b.gnutar-latest;
    gcc-buildbuild = b.gcc-latest;
    hostPlatform = platform;
  };
in
rec {
  gccSource = import ./recipes/gnu/gcc-source.nix {
    inherit (scope)
      lib
      bash
      fetchurl
      gnupatch
      xz
      gnused
      ;
    gnutar = b.gnutar-latest;
  };
  libc = (import ./gnu-libc-profile.nix { inherit bootstrap; }).libc;
  libgccDriver = import ./recipes/gnu/cross-wrapper.nix {
    inherit scope libc;
    cross = b.gnu-cross;
    runtime = b.gnu-core-bridge;
  };
  libgcc = call ./recipes/gnu/libgcc.nix (
    common
    // {
      gcc = libgccDriver;
      binutils-buildbuild = b.binutils;
      enableShared = true;
      installThreadHeaders = true;
      inherit libc;
      libc-headers = libc;
      libgmp = b.gcc16-gmp;
      libmpfr = b.gcc16-mpfr;
      libmpc = b.gcc16-mpc;
      libiberty = b.gcc16-libiberty;
    }
  );
  libstdcxxDriver = import ./recipes/gnu/cross-wrapper.nix {
    inherit scope libc;
    cross = b.gnu-cross;
    runtime = libgcc;
  };
  libstdcxx = call ./recipes/gnu/libstdcxx.nix (
    common
    // {
      gcc = libstdcxxDriver;
      inherit libc libgcc;
      dynamicLinkerGlob = "${libc}/lib/ld-linux-x86-64.so.2";
      staticLibgcc = false;
    }
  );
}
