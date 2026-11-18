{
  pkgs,
  tvp,
  name,
}:
let
  pname = "php-${name}";
  needsMysqlnd = name != "mysqlnd";
  introduction =
    {
      mysqlnd = {
        php = "5.3";
        tag = "5.3.29";
      };
      mysqli = {
        php = "5.0";
        tag = "5.0.5";
      };
      pdo_mysql = {
        php = "5.1";
        tag = "5.1.6";
      };
    }
    .${name};
  inherit (import ../bundled-releases.nix {
    inherit pkgs tvp;
    minPHP = "8.2";
    def.builder = ./build.nix;
  }) source versionTable;
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp name versionTable;
    phpPolicy = {
      kind = "bundled";
      requirements = {
        min = introduction.php;
        reason = "${name} first shipped with PHP ${introduction.php}. Each module uses its own PHP release's source and SDK.";
        source = "https://github.com/php/php-src/tree/php-${introduction.tag}/ext/${name}";
      };
    };
    inherit source;
    tests = import ./tests.nix { inherit pkgs tvp; };
    testDeps = pkgs.lib.optionalAttrs needsMysqlnd { mariadb = pkgs.mariadb.server; };
    meta = {
      homepage = "https://www.php.net/manual/en/${
        if name == "pdo_mysql" then "ref.pdo-mysql" else "book.${name}"
      }.php";
      license = pkgs.lib.licenses.php301;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
  requires = pkgs.lib.optional needsMysqlnd "mysqlnd";
}
