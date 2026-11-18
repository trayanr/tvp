{ pkgs, tvp }:
let
  name = "pdo_pgsql";
  pname = "php-${name}";
  postgresql = pkgs.postgresql_16;
  borrowed =
    reason:
    tvp.lib.packages.withConstraint {
      kind = "foreign";
      inherit reason;
    };
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps = {
          postgresql = borrowed "PDO_PGSQL needs the matching PostgreSQL SDK and client library." postgresql;
          openssl = borrowed "Link against the OpenSSL used by this PostgreSQL client." pkgs.openssl;
          krb5 = borrowed "Link against the Kerberos library used by this PostgreSQL client." pkgs.krb5;
          keyutils = borrowed "Resolve the Kerberos client library's link-time dependencies." pkgs.keyutils;
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
    testDeps.postgresql = borrowed "Runs the PostgreSQL integration test server." postgresql;
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
