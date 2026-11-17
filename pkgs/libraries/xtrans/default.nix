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
      releases."1.6.0" = "sha256-+q/qFmvyRRoXPZ1ZM1KUDsZAQUXF0dpcITQjzk01npI=";
    }
  ];
  pname = "xtrans";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.x.org/releases/individual/lib/";
      archive = "xtrans-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;
    testDeps.xorgproto = tvp.packages.xorgproto;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.xtrans = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
