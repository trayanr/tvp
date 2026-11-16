# Source-built GCC 13.3.0, constructed with the earlier closed GNU toolchain.
# No public package aliases or Nixpkgs providers participate in this composition.
{
  bootstrap ? import ../bootstrap { },
  platform ? import ./source-gnu/platform.nix,
  lib ? import ../bootstrap/owned-lib.nix { inherit (platform) system; },
  builder ? import ../lib/builder.nix { inherit lib; },
}:
let
  earlier = import ./gcc-16.2.0.nix { inherit lib builder platform; };
  constructionBase = earlier.full;
  reference = import ../bootstrap/source-full-gcc.nix { inherit bootstrap; };
  inherit (reference) prerequisites native harness;
  args = {
    tvp = {
      inherit builder;
    };
    inherit lib;
    base = constructionBase;
    src = import <nix/fetchurl.nix> {
      url = "https://mirrors.kernel.org/gnu/gcc/gcc-13.3.0/gcc-13.3.0.tar.xz";
      hash = "sha256-CEXpYhyVQ6E/SE6UWEpJ/8ASmXDpkUYkI1/B0GGgwIM=";
    };
    version = "13.3.0";
    patches = [
      ../pkgs/compilers/gcc/patches/program-prefix.patch
      ../pkgs/compilers/gcc/patches/linker-prefix.patch
      ../pkgs/compilers/gcc/patches/no-system-dirs.patch
    ];
    glibc = native.profile.libc;
    binutils = native.binutils;
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
    # The construction Python and every test-only provider are explicit earlier
    # source-built generations, independent of the public Python/GCC catalogue.
    python = harness.previous.profile;
    pythonConfig = harness.tools.python;
    inherit (reference) file;
    inherit (harness.previous.harness) dejagnu expect flock;
    graphviz = harness.packages.graphviz;
    fonts = harness.fonts;
  };
  compiler = builder {
    recipe = import ../pkgs/compilers/gcc/build-owned-13.3.0.nix;
    inherit args;
    dependencyNames = [
      "glibc"
      "binutils"
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
      "file"
    ];
    metadata = { };
    selection.kind = "source-gcc-13.3.0";
    testContext =
      package:
      (import ../lib/tests.nix { inherit lib; }).fromPackage {
        inherit builder package;
      };
    mkTests = package: {
      upstream-audit =
        (import ../pkgs/compilers/gcc/tests/upstream-13.3.0.nix {
          inherit lib package;
          tvp = {
            inherit builder;
          };
        }).acceptance;
    };
  };
  make =
    recipe: arguments:
    builder {
      inherit recipe;
      args = arguments;
      dependencyNames = builtins.attrNames arguments;
      metadata = { };
      selection.kind = "source-gcc-13.3.0-driver";
      mkTests = _: { };
    };
  driver = import ../bootstrap/source-full-gcc-driver.nix {
    inherit bootstrap compiler make;
    libc = native.profile.libc;
  };
  full = (import ./tiers { inherit lib builder; }).mkStage {
    name = "gcc_13_3_0";
    inherit platform;
    previous = constructionBase;
    tools = (builtins.removeAttrs constructionBase.tools [ "binutils" ]) // {
      gcc = driver;
    };
    baselineTools = constructionBase.baselineTools;
    referencePackages = constructionBase.referencePackages ++ [
      compiler
      driver
      driver.bintools
      driver.libc
    ];
  };
in
{
  inherit compiler driver constructionBase;
  base = full;
  # This procedure produces one complete GCC13 generation. Reusing earlier
  # GCC16 construction stages does not make them additional GCC13 products.
  family = {
    inherit full;
  };
}
