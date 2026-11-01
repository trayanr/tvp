# Test consumers select package-owned tool variants. These rebuilds validate
# alternative toolchain inputs; they do not define reusable production tools.
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
  buildConsumer =
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
    m4 = p.m4_1_4_21;
    pkg-config = p."pkg-config_0_29_2";
    autoconf = p.autoconf_2_73;
  };
  packages = {
    bison = p.bison_3_8_2;
    texinfo = p.texinfo_7_1;
    which = p.which_2_21;
    python-minimal = p."python-minimal_3_12_5";
  };
  # Ordinary tools now select normal canonical dependencies, rather than
  # reaching into this base's private assembly stages for Perl, Bash or file.
  runtimeDependencies = {
    inherit (p)
      perl
      bash
      ncurses
      file
      zlib
      xz
      zstd
      bzip2
      ;
  };

  consumers = rec {
    binutils = buildConsumer p.binutils_2_42 {
      inherit (packages) bison texinfo;
      inherit (components) perl;
      inherit (components.libraries) zlib zstd;
      inherit (inputs) pkg-config;
    };
    gcc = buildConsumer p.gcc_13_3_0 {
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
    glibc = buildConsumer p.glibc_2_39 {
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
  # These validation roots combine bootstrap-base consumers with canonical
  # tools. The latter retain their selected base's wrapper runtime helpers.
  canonicalToolRuntimePaths = lib.unique (
    lib.concatMap (package: tvp.bases.${package.tvp.base}.ownership.allowedRuntimePaths) (
      lib.attrValues inputs ++ lib.attrValues packages ++ lib.attrValues runtimeDependencies
    )
  );
  tests = suite (tvp.lib.packages.merge { inherit inputs packages; });
  consumerTests = suite consumers;
  runtimePaths =
    lib.attrValues inputs
    ++ lib.attrValues packages
    ++ lib.attrValues runtimeDependencies
    ++ lib.attrValues consumers
    ++ [
      consumers.glibc.bin
      # glibc installs symlinks to its selected Linux UAPI headers.
      consumers.glibc.tvp.deps.linuxHeaders
    ];
}
