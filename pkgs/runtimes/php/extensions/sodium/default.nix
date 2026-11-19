{ pkgs, tvp }:
let
  name = "sodium";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps.libsodium = tvp.packages.libsodium;
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
        min = "7.2";
        reason = "Sodium first shipped with PHP 7.2. Older releases used the separate PECL extension.";
        source = "https://www.php.net/manual/en/sodium.installation.php";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "Cryptographic functions backed by libsodium";
      homepage = "https://www.php.net/manual/en/book.sodium.php";
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
