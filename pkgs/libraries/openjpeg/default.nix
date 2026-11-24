{ pkgs, tvp }:
let
  pname = "openjpeg";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = { inherit (tvp.packages) libpng libtiff lcms2 zlib; };
      };
      releases."2.5.4" = "sha256-ppX74ZwBZfKVqFMbHk6FXNlNCHXS+I7EthCAZ34nGIo=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/uclouvain/openjpeg/archive/refs/tags/v${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/uclouvain/openjpeg";
        normalise =
          tag:
          if builtins.match "v[0-9]+\\.[0-9]+\\.[0-9]+" tag == null then
            null
          else
            pkgs.lib.removePrefix "v" tag;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.openjpeg = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
