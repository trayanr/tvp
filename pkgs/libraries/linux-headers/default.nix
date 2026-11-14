{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."linux-headers";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    standardTools = {
      gnumake = earlier.tools.make;
      gnutar = earlier.tools.tar;
      xz = earlier.tools.xz;
      findutils = earlier.tools.findutils;
      sed = earlier.tools.sed;
      grep = earlier.tools.grep;
      gawk = earlier.tools.gawk;
      diffutils = earlier.tools.diffutils;
      perl = tvp.packages.perl_5;
    };
  };
  pname = "linux-headers";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-6.9-native.nix;
        base = profileBase;
        deps = { };
      };
      releases = {
        "6.9" = "sha256-JPoB+5icej4oRT8Rd5kWhxN2bhGcU4HawwEV8Y8mgUk=";
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
        url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."linux-headers" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
