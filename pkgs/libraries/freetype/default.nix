{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkg-config = tvp.packages.pkg-config;
          zlib = tvp.packages.zlib_1;
          bzip2 = tvp.packages.bzip2_1;
        };
      };
      releases."2.15.0" = "sha256-k81H63GcMlEH8tPPCH0GKZ6UTDtIpAtVU3MCME3qHdU=";
    }
  ];
  pname = "freetype";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://download.savannah.gnu.org/releases/freetype/";
      archive = "freetype-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.freetype = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
