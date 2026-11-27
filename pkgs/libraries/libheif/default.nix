{ tvp, ... }:
let
  pname = "libheif";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          brotli = tvp.packages.brotli;
          libde265 = tvp.packages.libde265_1;
          jpeg = tvp.packages.libjpeg-turbo;
          png = tvp.packages.libpng_1;
          openjpeg = tvp.packages.openjpeg;
          tiff = tvp.packages.libtiff;
          webp = tvp.packages.libwebp;
          x265 = tvp.packages.x265_4;
          zlib = tvp.packages.zlib_1;
        };
      };
      releases."1.23.7" = "sha256-90g+gYUD6mIkyIY+SlasAscIkCGphHLIEcEqoZ+vJHU=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/strukturag/libheif/releases/download/v${version}/libheif-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/strukturag/libheif";
        prefix = "v";
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
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
