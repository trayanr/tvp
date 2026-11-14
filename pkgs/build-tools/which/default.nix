{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."which";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      gawk = tvp.packages.gawk;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      patchelf = tvp.packages.patchelf;
    };
  };
  pname = "which";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.21-native.nix;
        base = profileBase;
        deps = {
          binutils = tvp.packages.binutils;
        };
      };
      releases = {
        "2.21" = "sha256-9KJFuUEks3fYtJZGv0IfkVXTaqdhS26/g3BdP/x26q0=";
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
        url = "https://mirrors.kernel.org/gnu/which/which-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."which" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
