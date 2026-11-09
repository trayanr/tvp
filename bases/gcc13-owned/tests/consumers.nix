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
  historical = import ./construction-tools.nix { inherit pkgs tvp; };
  p = tvp.packages // {
    php_8_5_12 =
      (import ../../../pkgs/runtimes/php/legacy.nix {
        inherit pkgs;
        tvp = tvp // {
          packages = tvp.packages // {
            libtool_2 = historical.libtool;
          };
        };
      }).canonical.php_8_5_12;
  };
  testPkgs = pkgs // {
    inherit stdenv;
    glibc = components.libc;
    gnumake = components.floor.gnumake;
  };
  buildConsumer =
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
  zlib = buildConsumer p.zlib_1_3_2 { };
  openssl = buildConsumer p.openssl_3_5_7 {
    perl = components.perl;
  };
  libxml2 = buildConsumer p.libxml2_2_15_3 {
    inherit zlib;
  };
  tcl = buildConsumer p.tcl_8_6_18 {
    inherit zlib;
  };
  sqlite = buildConsumer p.sqlite_3_53_4 {
    inherit tcl;
    inherit (components.libraries) readline;
  };
  php = buildConsumer p.php_8_5_12 {
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
