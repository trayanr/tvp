{ tvp, ... }:
let
  pname = "djvulibre";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          jpeg = tvp.packages.libjpeg-turbo;
          tiff = tvp.packages.libtiff;
        };
      };
      releases."3.5.30" = "sha256-7l5FfUz+vlZvlLmeXj08x/XHndt0HCrCui5FbwAylkQ=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://downloads.sourceforge.net/project/djvu/DjVuLibre/${version}/djvulibre-${version}.tar.gz";
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
