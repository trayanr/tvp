{ pkgs, tvp }:
let
  retained = import ./retained.nix { inherit pkgs tvp; };
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = { };
      };
      releases."1.2.16.1" = "sha256-90Dbf0iCVZRP/UQoQW7jOQqWdChWkWQz30aMKBQ2SA4=";
    }
  ];
  pname = "alsa-lib";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://www.alsa-project.org/files/pub/lib/alsa-lib-${version}.tar.bz2";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;
    testDeps.pkgConfig = tvp.packages.pkg-config;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.alsa-lib = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
