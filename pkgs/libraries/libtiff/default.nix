{ tvp, ... }:
let
  pname = "libtiff";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          jpeg = tvp.packages.libjpeg-turbo;
          inherit (tvp.packages)
            zlib
            zstd
            xz
            libwebp
            ;
        };
      };
      releases."4.7.2" = "sha256-ZyvX0QruRgYXGvuGTzVwuDNA9qM+LBhtwFEvcUX/32o=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://download.osgeo.org/libtiff/";
      archive = "tiff-{version}.tar.gz";
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libtiff = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
