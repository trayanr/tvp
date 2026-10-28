# Additional tools built on the completed base. Integration builds replace the
# borrowed helpers without redefining the committed bootstrap graph.
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
      }
      // lib.optionalAttrs (package ? mkTests) {
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
  inputs = {
    m4 = build p.m4_1_4_21 { };
    pkg-config = build p."pkg-config_0_29_2" { };
  };
  packages = {
    bison = build p.bison_3_8_2 {
      inherit (inputs) m4;
      inherit (components) perl;
    };
    texinfo = build p.texinfo_7_1 {
      inherit (components) perl;
      inherit (components.libraries) ncurses;
      localeTools = components.libc.bin;
    };
    which = build p.which_2_21 { };
    python-minimal = build p."python-minimal_3_12_5" {
      inherit (components.floor) bash;
    };
  };
  consumers = rec {
    binutils = build p.binutils_2_42 {
      inherit (packages) bison texinfo;
      inherit (components) perl;
      inherit (components.libraries) zlib zstd;
      inherit (inputs) pkg-config;
    };
    gcc = build p.gcc_13_3_0 {
      inherit binutils;
      inherit (packages) texinfo which;
      inherit (components) perl;
      glibc = components.libc;
      inherit (components.libraries)
        gmp
        mpfr
        mpc
        isl
        zlib
        zstd
        libxcrypt
        ;
    };
    glibc = build p.glibc_2_39 {
      inherit gcc binutils;
      inherit (packages) bison;
      python3Minimal = packages.python-minimal;
      inherit (components) perl;
    };
  };
  suite = lib.concatMapAttrs (
    name: package: lib.mapAttrs' (test: drv: lib.nameValuePair "${name}-${test}" drv) package.tests
  );
in
{
  inherit inputs packages consumers;
  tests = suite (tvp.lib.packages.merge { inherit inputs packages; });
  consumerTests = suite consumers;
  runtimePaths =
    lib.attrValues inputs
    ++ lib.attrValues packages
    ++ lib.attrValues consumers
    ++ [ consumers.glibc.bin ];
}
