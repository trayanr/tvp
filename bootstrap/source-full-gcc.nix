# Opt-in complete compiler. No catalogue/default-base selection.
{
  bootstrap ? import ./. { },
}:
let
  harness = import ./source-gcc-graphviz-tests.nix { inherit bootstrap; };
  prerequisites = harness.previous.harness.prerequisites;
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
  compiler = make (import ../pkgs/compilers/gcc/owned/build-16.2.0.nix) {
    inherit
      lib
      base
      bash
      coreutils
      source
      ;
    version = "16.2.0";
    libc = native.profile.libc;
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
    python = harness.previous.profile;
    pythonConfig = harness.tools.python;
    inherit file;
    inherit (harness.previous.harness) dejagnu expect flock;
    graphviz = harness.packages.graphviz;
    fonts = harness.fonts;
    tools = map (n: prerequisites.tools.${n}) [
      "tar"
      "xz"
      "gzip"
      "findutils"
      "sed"
      "grep"
      "gawk"
      "diffutils"
    ];
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
