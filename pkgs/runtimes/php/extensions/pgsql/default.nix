{ pkgs, tvp }:
let
  name = "pgsql";
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
    phpPolicy.kind = "bundled";
    tests = import ./tests.nix { inherit tvp; };
    testDeps.postgresql = postgresql;
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
