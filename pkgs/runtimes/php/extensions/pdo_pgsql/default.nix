{ pkgs, tvp }:
let
  postgresql = pkgs.postgresql_16;
in
import ../bundled-family.nix {
  inherit pkgs tvp;
  name = "pdo_pgsql";
  phpRequirements = {
    min = "5.1";
    reason = "The bundled PDO PostgreSQL driver first shipped with PHP 5.1.";
    source = "https://github.com/php/php-src/tree/php-5.1.0/ext/pdo_pgsql";
  };
  opts = {
    libraries = [ postgresql.lib ];
    linkLibraries = [
      pkgs.openssl
      pkgs.krb5
      pkgs.keyutils
    ];
    configureOptions = [ "--with-pdo-pgsql=${postgresql}" ];
  };
  testDeps = { inherit postgresql; };
  tests = import ./tests.nix { inherit tvp; };
  meta = {
    description = "PHP PDO driver for PostgreSQL";
    homepage = "https://www.php.net/manual/en/ref.pdo-pgsql.php";
  };
}
