{ pkgs, tvp }:
let
  name = "gd";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps = {
          zlib = tvp.packages.zlib_1;
          libpng = tvp.packages.libpng;
          libjpeg-turbo = tvp.packages.libjpeg-turbo;
          libwebp = tvp.packages.libwebp;
          freetype = tvp.packages.freetype;
        };
      };
    })
    source
    versionTable
    ;
  family = tvp.lib.php.mkExtensionFamily {
    inherit
      tvp
      name
      versionTable
      source
      ;
    phpPolicy.kind = "bundled";
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "Image creation and processing with bundled libgd";
      homepage = "https://www.php.net/manual/en/book.image.php";
      license = pkgs.lib.licenses.php301;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
