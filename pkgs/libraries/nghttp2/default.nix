{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."nghttp2";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      xz = tvp.packages.xz;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      gawk = tvp.packages.gawk;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      pkg-config = tvp.packages.pkg-config;
    };
  };
  pname = "nghttp2";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.70.0-native.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
        };
      };
      releases = {
        "1.70.0" = "sha256-4FyxOI6so4MK3tTM8gBEtuGsGmFBHcyhGwQ3xChci8I=";
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
        url = "https://github.com/nghttp2/nghttp2/releases/download/v${version}/nghttp2-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."nghttp2" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
