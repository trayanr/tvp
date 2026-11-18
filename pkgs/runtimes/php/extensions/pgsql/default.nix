{ pkgs, tvp }:
let
  name = "pgsql";
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
          postgresql = borrowed "PGSQL needs the matching PostgreSQL SDK and client library." postgresql;
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
    phpPolicy.kind = "bundled";
    tests = import ./tests.nix { inherit tvp; };
    testDeps.postgresql = borrowed "Runs the PostgreSQL integration test server." postgresql;
    meta = {
      description = "PHP native client for PostgreSQL";
      homepage = "https://www.php.net/manual/en/book.pgsql.php";
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
