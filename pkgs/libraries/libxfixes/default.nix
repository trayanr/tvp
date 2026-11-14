{ pkgs, tvp }:
let
  retained = (import ./retained.nix { inherit pkgs tvp; }).packageArgs;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
          libx11 = tvp.packages.libx11_1;
          xorgproto = tvp.packages.xorgproto;
          xtrans = tvp.packages.xtrans_1;
          libxcb = tvp.packages.libxcb_1;
          libxau = tvp.packages.libxau_1;
          libxdmcp = tvp.packages.libxdmcp_1;
        };
      };
      releases."6.0.2" = "sha256-OfEV1y2cX4ER5GhBZNPWjMH9Ifmyf/JAGwj938D0Cbo=";
    }
  ];
  pname = "libxfixes";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://www.x.org/releases/individual/lib/libXfixes-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxfixes = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
