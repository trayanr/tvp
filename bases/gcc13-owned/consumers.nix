# Exercise real package recipes on the assembled base. Dependencies are rebuilt
# too: changing only the top-level stdenv would still test borrowed libc graphs.
{
  pkgs,
  tvp,
  stdenv,
  components,
}:
let
  inherit (pkgs) lib;
  p = tvp.packages;
  testPkgs = pkgs // {
    inherit stdenv;
    glibc = components.libc;
    gnumake = components.floor.gnumake;
  };
  build =
    package: args:
    (package.override (
      {
        inherit stdenv;
        mkTests = package.mkTests.override { pkgs = testPkgs; };
      }
      // args
    )).overrideAttrs
      (old: {
        passthru = old.passthru // {
          tvp = old.passthru.tvp // {
            base = "gcc13-owned";
            canonical = false;
          };
        };
      });
  zlib = build p.zlib_1_3_2 { };
  openssl = build p.openssl_3_5_7 {
    perl = components.perl;
  };
  libxml2 = build p.libxml2_2_15_3 {
    inherit zlib;
  };
  tcl = build p.tcl_8_6_18 {
    inherit zlib;
  };
  sqlite = build p.sqlite_3_53_4 {
    inherit tcl;
    inherit (components.libraries) readline;
  };
  php = build p.php_8_5_12 {
    inherit
      zlib
      openssl
      libxml2
      sqlite
      ;
    inherit (components.libraries) readline ncurses;
  };
  packages = {
    inherit
      zlib
      openssl
      libxml2
      tcl
      sqlite
      php
      ;
  };
in
{
  inherit packages;
  tests = lib.concatMapAttrs (
    name: package: lib.mapAttrs' (test: drv: lib.nameValuePair "${name}-${test}" drv) package.tests
  ) packages;
}
