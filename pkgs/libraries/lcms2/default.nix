{ pkgs, tvp }:
let
  pname = "lcms2";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          jpeg = tvp.packages.libjpeg-turbo;
          inherit (tvp.packages) libtiff zlib;
        };
      };
      releases."2.20" = "sha256-GP9VBPqcyKKx81kRgNkOrRbIoup45TBSO0bqtw4cprk=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://github.com/mm2/Little-CMS/releases/download/lcms${version}/lcms2-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/mm2/Little-CMS";
        normalise =
          tag:
          if builtins.match "lcms2(\\.[0-9]+)+" tag == null then
            null
          else
            pkgs.lib.removePrefix "lcms" tag;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.lcms2 = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
