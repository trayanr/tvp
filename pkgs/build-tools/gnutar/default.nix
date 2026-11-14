{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."gnutar";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  locale = import ../../../lib/tests/gnu-locale.nix {
    builder = tvp.builder;
    base = full;
    bash = full.shell;
    coreutils = full.coreutils;
    tar = full.standardTools.gnutar;
    xz = full.standardTools.xz;
    libc = full.compiler.libc;
  };
  profileBase = full.override {
    standardTools = {
      gnumake = earlier.tools.make;
      gnutar = earlier.tools.tar;
      xz = earlier.tools.xz;
      gzip = earlier.tools.gzip;
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      sed = earlier.tools.sed;
      grep = earlier.tools.grep;
      gawk = earlier.tools.gawk;
      diffutils = earlier.tools.diffutils;
      findutils = earlier.tools.findutils;
      perl = earlier.tools.perl;
    };
  };
  pname = "gnutar";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.32-native.nix;
        base = profileBase;
        deps = {
          acl = tvp.lib.packages.withConstraint {
            reason = "Tar's static three-argument acl_*_at helpers collide with ACL 2.4; retain the supported 2.3 API line.";
          } tvp.packages.acl_2_3;
          attr = tvp.packages.attr_2;
          binutils = earlier.tools.binutils;
        };
      };
      releases = {
        "1.32" = "sha256-0NOuB/EDMjvoCbw+rA3MOG1SxSYkmf4FURrEeIrx/dg=";
        "1.33" = "sha256-Zqg0Sx3IOkEdMRvRVH4BduVswxHyjulKMPhNr7PZBn4=";
        "1.34" = "sha256-Y769JoecXh7qQ1Lw0DyZH5Zq6z3es8dEXJAlaNVBHSg=";
      };
    }
    {
      def = {
        builder = ./build-1.35-native.nix;
        base = profileBase;
        deps = {
          acl = tvp.lib.packages.withConstraint {
            reason = "Tar's static three-argument acl_*_at helpers collide with ACL 2.4; retain the supported 2.3 API line.";
          } tvp.packages.acl_2_3;
          attr = tvp.packages.attr_2;
          binutils = earlier.tools.binutils;
        };
      };
      releases = {
        "1.35" = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    inherit locale;
    gzip = tvp.packages.gzip;
    bzip2 = tvp.packages.bzip2_1;
    xz = tvp.packages.xz_5;
    zstd = tvp.packages.zstd_1;
  };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/tar/tar-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily // {
    extraArgs.mkTests =
      pkgs.lib.makeOverridable
        (
          {
            tests,
            locale,
            helpers ? null,
          }:
          package:
          (tests {
            package = package // {
              testConfiguration = {
                inherit locale helpers;
              };
            };
            lib = pkgs.lib;
            context = package.testContext;
          })
        )
        {
          tests = import ./tests;
          inherit locale;
        };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."gnutar" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
