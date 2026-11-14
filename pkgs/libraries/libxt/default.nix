{ pkgs, tvp }:
let
  retained = (import ./retained.nix { inherit pkgs tvp; }).packageArgs;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
          libsm = tvp.packages.libsm_1;
          libice = tvp.packages.libice_1;
          libx11 = tvp.packages.libx11_1;
          xorgproto = tvp.packages.xorgproto;
          xtrans = tvp.packages.xtrans_1;
          libxcb = tvp.packages.libxcb_1;
          libxau = tvp.packages.libxau_1;
          libxdmcp = tvp.packages.libxdmcp_1;
        };
      };
      releases."1.3.1" = "sha256-4Kd0szMk9NTAWxmepFBQ+HIGWG2BZV+L7026Q02TEog=";
    }
  ];
  pname = "libxt";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://www.x.org/releases/individual/lib/libXt-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxt = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
