{ pkgs, tvp }:
let
  name = "intl";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps = {
          icu = tvp.lib.packages.withConstraint {
            kind = "foreign";
            reason = "PHP intl requires ICU, which TVP does not package yet.";
          } pkgs.icu;
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
        min = "5.3.0";
        reason = "PHP first bundled intl in 5.3.0.";
        source = "https://github.com/php/php-src/tree/php-5.3.0/ext/intl";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP internationalization support through ICU";
      homepage = "https://www.php.net/manual/en/book.intl.php";
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
