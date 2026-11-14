{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."zip";
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.zip;
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
  pname = "zip";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-3.0-native.nix;
        base = profileBase;
        deps = {
          bzip2 = tvp.packages.bzip2_1;
          binutils = earlier.tools.binutils;
        };
        opts.buildFeatures = {
          cflags = "-Wno-error=implicit-function-declaration -Wno-error=implicit-int";
          hardeningDisable = [ "format" ];
        };
      };
      releases = {
        "3.0" = "sha256-8Oi7H5t+sLAShUlaJpnfOkt2Z4TBdlqPGu7fY8CAY2k=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    unzip = tvp.packages.unzip;
  };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://downloads.sourceforge.net/infozip/zip30.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily // {
    extraArgs.mkTests =
      pkgs.lib.makeOverridable
        (
          { tests, unzip }:
          package:
          (tests {
            package = package // {
              tvp = package.tvp // {
                declaredTestDependencies = package.tvp.declaredTestDependencies // {
                  inherit unzip;
                };
              };
            };
            lib = pkgs.lib;
            context = package.testContext;
          })
        )
        {
          tests = import ./tests;
          unzip = tvp.packages.unzip;
        };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."zip" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
