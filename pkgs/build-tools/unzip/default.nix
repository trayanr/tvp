{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."unzip";
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.unzip;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      gawk = tvp.packages.gawk;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      patchelf = tvp.packages.patchelf;
      python = tvp.packages.python_3;
    };
  };
  pname = "unzip";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-6.0-native.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
        };
        opts.buildFeatures = {
          cflags = "-fcommon -std=gnu17 -Wno-error=implicit-int -Wno-error=implicit-function-declaration";
          hardeningDisable = [ "format" ];
        };
      };
      releases = {
        "6.0" = "sha256-A22WmRZG0ESe0KqVLk++IbR2zplKvCduSdMOaGcIvTc=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    zip = tvp.packages.zip;
  };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://downloads.sourceforge.net/infozip/unzip60.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily // {
    extraArgs.mkTests =
      pkgs.lib.makeOverridable
        (
          { tests, zip }:
          package:
          (tests {
            package = package // {
              tvp = package.tvp // {
                declaredTestDependencies = package.tvp.declaredTestDependencies // {
                  inherit zip;
                };
              };
            };
            lib = pkgs.lib;
            context = package.testContext;
          })
        )
        {
          tests = import ./tests;
          zip = tvp.packages.zip;
        };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."unzip" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
