{ tvp, ... }:
let
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
    source = tvp.lib.sources.directory {
      url = "https://www.x.org/releases/individual/proto/";
      archive = "xorgproto-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.xorgproto = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
