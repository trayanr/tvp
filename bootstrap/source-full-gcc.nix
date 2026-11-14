# Opt-in complete compiler. No catalogue/default-base selection.
{
  bootstrap ? import ./. { },
}:
let
  harness = import ./source-gcc-graphviz-tests.nix { inherit bootstrap; };
  prerequisites = import ./source-full-gcc-prerequisites.nix { inherit bootstrap; };
  native = prerequisites.native;
  inherit (native.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-full-gcc";
      mkTests = _: { };
    };
  source = make (import ../pkgs/compilers/gcc/owned/source-16.2.0.nix) {
    inherit
      lib
      base
      bash
      coreutils
      ;
    src = native.sources.gcc;
    version = "16.2.0";
    layoutPatch = native.sources.layout;
    patches = [
      # The layout patch renamed libsubdir; retain in-tree libgcc copyback.
      ../pkgs/compilers/gcc/patches/16.2.0-full-libgcc-copyback.patch
      ../pkgs/compilers/gcc/patches/no-system-dirs.patch
      ../pkgs/compilers/gcc/patches/16.2.0-program-prefix.patch
      ../pkgs/compilers/gcc/patches/16.2.0-linker-prefix.patch
    ];
    libc = native.profile.libc;
    inherit (prerequisites.tools) python xz patch;
    gnutar = prerequisites.tools.tar;
  };
  testSources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-full-gcc-test-sources.json)
  );
  file = make (import ../pkgs/build-tools/file/owned/build-5.48.nix) {
    inherit
      lib
      base
      bash
      coreutils
      ;
    src = testSources.file;
    version = "5.48";
    gnutar = prerequisites.tools.tar;
    gzip = prerequisites.tools.gzip;
    gnumake = prerequisites.tools.make;
    inherit (prerequisites) zlib zstd;
    inherit (native.prior.prerequisites) xz bzip2;
    tools = map (n: prerequisites.tools.${n}) [
      "sed"
      "grep"
      "gawk"
      "diffutils"
      "findutils"
    ];
  };
  # Public and construction compilers use one complete procedure. Earlier
  # providers are selected here, before the public full base exists.
  compiler = builder {
    recipe = import ../pkgs/compilers/gcc/native/build-16.2.0.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit
        lib
        base
        bash
        coreutils
        ;
      src = native.sources.gcc;
      version = "16.2.0";
      layoutPatch = native.sources.layout;
      patches = [
        ../pkgs/compilers/gcc/patches/16.2.0-full-libgcc-copyback.patch
        ../pkgs/compilers/gcc/patches/no-system-dirs.patch
        ../pkgs/compilers/gcc/patches/16.2.0-program-prefix.patch
        ../pkgs/compilers/gcc/patches/16.2.0-linker-prefix.patch
      ];
      glibc = native.profile.libc;
      inherit (prerequisites)
        gmp
        mpfr
        mpc
        isl
        zlib
        zstd
        libxcrypt
        texinfo
        which
        perl
        ;
      binutils = native.binutils;
      gnumake = prerequisites.tools.make;
      python = prerequisites.tools.python;
      patchelf = prerequisites.tools.patchelf;
      gnutar = prerequisites.tools.tar;
      inherit (prerequisites.tools)
        xz
        gzip
        patch
        findutils
        sed
        grep
        gawk
        diffutils
        ;
      # file remains configure-visible pending a source-bound role audit.
      inherit file;
      # The validation profile and harness never enter production commands.
      testPython = harness.previous.profile;
      pythonConfig = harness.tools.python;
      inherit (harness.previous.harness) dejagnu expect flock;
      graphviz = harness.packages.graphviz;
      fonts = harness.fonts;
    };
    dependencyNames = [
      "glibc"
      "binutils"
      "gnumake"
      "gmp"
      "mpfr"
      "mpc"
      "isl"
      "zlib"
      "zstd"
      "libxcrypt"
      "texinfo"
      "which"
      "perl"
      "python"
      "patchelf"
      "gnutar"
      "xz"
      "gzip"
      "patch"
      "findutils"
      "sed"
      "grep"
      "gawk"
      "diffutils"
      "file"
    ];
    metadata = { };
    selection.kind = "source-full-gcc";
    testContext =
      package: (import ../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests = package: {
      upstream-audit =
        (import ../pkgs/compilers/gcc/tests/upstream-16.2.0.nix {
          inherit package lib;
          tvp = {
            inherit builder;
          };
        }).acceptance;
    };
  };
  driver = import ./source-full-gcc-driver.nix {
    inherit bootstrap compiler make;
    libc = native.profile.libc;
  };
in
{
  inherit
    testSources
    file
    source
    compiler
    driver
    harness
    prerequisites
    native
    ;
  composition = import ./source-base.nix {
    inherit bootstrap;
    compiler = driver;
  };
}
