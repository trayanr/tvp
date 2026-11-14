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
      releases."2026.1" = "sha256-+b/kqe2MirnSo7DUl5fwRgUtrdBreotF2/+v+xN+gpA=";
    }
  ];
  pname = "xorgproto";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://www.x.org/releases/individual/proto/xorgproto-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.xorgproto = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
