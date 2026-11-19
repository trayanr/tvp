{ pkgs, tvp }:
let
  name = "pdo_pgsql";
  pname = "php-${name}";
  postgresql = tvp.packages.postgresql_16;
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps = {
          inherit postgresql;
          inherit (postgresql.specification) openssl krb5 keyutils;
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
        min = "5.1";
        reason = "The bundled PDO PostgreSQL driver first shipped with PHP 5.1.";
        source = "https://github.com/php/php-src/tree/php-5.1.0/ext/pdo_pgsql";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    testDeps.postgresql = postgresql;
    meta = {
      description = "PHP PDO driver for PostgreSQL";
      homepage = "https://www.php.net/manual/en/ref.pdo-pgsql.php";
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
