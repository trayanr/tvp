{ pkgs, tvp }:
let
  name = "zip";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps = {
          libzip = tvp.packages.libzip;
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
    phpPolicy = {
      kind = "bundled";
      requirements = {
        min = "5.2";
        reason = "The bundled Zip extension for creating and editing archives was introduced in PHP 5.2.";
        source = "https://www.php.net/releases/5_2_0.php";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP extension for reading and writing ZIP archives";
      homepage = "https://www.php.net/zip";
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
