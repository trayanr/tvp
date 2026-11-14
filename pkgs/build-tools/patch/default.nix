{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."patch";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patch = earlier.tools.patch;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      xz = tvp.packages.xz;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      gawk = tvp.packages.gawk;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      patchelf = tvp.packages.patchelf;
    };
  };
  pname = "patch";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.7.6-native.nix;
        base = profileBase;
        deps = {
          binutils = tvp.packages.binutils;
        };
      };
      releases = {
        "2.7.6" = "sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=";
      };
    }
    {
      def = {
        builder = ./build-2.8-native.nix;
        base = profileBase;
        deps = {
          binutils = tvp.packages.binutils;
        };
      };
      releases = {
        "2.8" = "sha256-+Hzuae7CtPy/YKOWsDCtaqNBXxkqpffuhMrV4R9/WuM=";
      };
    }
    {
      def = {
        builder = ./build-2.8.1-native.nix;
        base = profileBase;
        deps = {
          binutils = tvp.packages.binutils;
        };
        patches = [
          {
            file = ./patches/bad-filenames-input.patch;
            reason = "Precompute invalid-filename input without changing rejection assertions or hiding the EPIPE race.";
          }
        ];
      };
      releases = {
        "2.8.1" = "sha256-MkDHlZxTR8jtNH48QgHAM3v0JA1c8J1oiJ5Y7qujDhc=";
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
        url = "https://mirrors.kernel.org/gnu/patch/patch-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."patch" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
