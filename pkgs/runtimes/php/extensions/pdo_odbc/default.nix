{ pkgs, tvp }:
let
  name = "pdo_odbc";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps.unixodbc = tvp.packages.unixodbc;
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
        min = "5.1";
        reason = "PHP first bundled PDO_ODBC with PHP 5.1.";
        source = "https://github.com/php/php-src/tree/php-5.1.0/ext/pdo_odbc";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    testDeps = {
      unixodbc = tvp.packages.unixodbc;
      sqliteodbc = tvp.packages.sqliteodbc;
    };
    meta = {
      description = "PHP PDO driver for unixODBC";
      homepage = "https://www.php.net/manual/en/ref.pdo-odbc.php";
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
