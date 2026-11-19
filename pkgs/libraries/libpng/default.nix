{ tvp, ... }:
let
  pname = "libpng";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.zlib = tvp.packages.zlib_1;
      };
      releases."1.6.59" = "sha256-2A3So4o3+APLm2rHsUvW503cO2VHgKg4C9+TUj/bQ4k=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://download.sourceforge.net/libpng/libpng-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/pnggroup/libpng.git";
        prefix = "v";
        include = version: builtins.match "[0-9]+([.][0-9]+)+" version != null;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
