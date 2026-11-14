{ pkgs, tvp }:
let
  retained = (import ./retained.nix { inherit pkgs tvp; }).packageArgs;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
        };
      };
      releases."1.6.0" = "sha256-+q/qFmvyRRoXPZ1ZM1KUDsZAQUXF0dpcITQjzk01npI=";
    }
  ];
  pname = "xtrans";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://www.x.org/releases/individual/lib/xtrans-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;
    testDeps.xorgproto = tvp.packages.xorgproto;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.xtrans = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
