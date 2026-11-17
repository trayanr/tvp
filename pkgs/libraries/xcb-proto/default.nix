{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
          generatorPython = tvp.packages.python_3;
        };
      };
      releases."1.17.0" = "sha256-LBus0hEPR5n3TebrtxS5TPb4D7ESMWsSGUgP0iViFIw=";
    }
  ];
  pname = "xcb-proto";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://xcb.freedesktop.org/dist/";
      archive = "xcb-proto-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.xcb-proto = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
