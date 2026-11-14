{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."zstd";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      gnumake = tvp.packages.gnumake;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
    };
  };
  variantBase =
    (import ../../../bases/tiers/construction.nix {
      inherit (pkgs) lib;
      builder = tvp.builder;
    } tvp.bases.default).override
      {
        shell = tvp.packages.bash;
        coreutils = tvp.packages.coreutils;
        standardTools = {
          gnumake = tvp.packages.gnumake;
          gnutar = tvp.packages.gnutar;
          gzip = tvp.packages.gzip;
          sed = tvp.packages.gnused;
          grep = tvp.packages.gnugrep;
          diffutils = tvp.packages.diffutils;
          python = tvp.packages.python-build_3;
          patchelf = tvp.packages.patchelf_0;
        };
      };
  pname = "zstd";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.5.6-native.nix;
        base = profileBase;
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          binutils = earlier.tools.binutils;
        };
      };
      releases = {
        "1.5.6" = "sha256-jCngbPQqrMHq/EB3ri7Gxvy5amJhV+BZPV6Co0/UA8E=";
      };
    }
    {
      def = {
        builder = ./build-1.5.7-native.nix;
        base = profileBase;
        deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          binutils = earlier.tools.binutils;
        };
      };
      releases = {
        "1.5.7" = "sha256-6zPlH0mhXgI5UM14Jcp0pKK0Pbg1SCWsJPwbfuCeb6M=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // { };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/facebook/zstd/releases/download/v${version}/zstd-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily // {
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { tests }:
      package:
      (tests {
        package = package;
        lib = pkgs.lib;
        context = package.testContext;
      })
      // pkgs.lib.optionalAttrs ((package.tvp.variant or null) == "build-steps") {
        runtime-expectation = import ../../../lib/runtime-expectation.nix { inherit (pkgs) lib; } {
          inherit package;
          stdenv = tvp.bases.default.stdenv;
          python = tvp.packages.python_3;
        };
      }
    ) { tests = import ./tests; };
  };
  canonical = tvp.lib.packages.mkVersions family;
  variants = tvp.lib.packages.mkVariants (
    family
    // {
      inherit pkgs;
      profiles.build-steps = {
        base = variantBase;
        versions."1.5.7".deps = {
          zlib = tvp.packages.zlib_1;
          xz = tvp.packages.xz_5;
          binutils = tvp.bases.default.stdenv.cc.bintools.bintools;
        };
      };
    }
  );
in
{
  recipes."zstd" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  inherit variants;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
