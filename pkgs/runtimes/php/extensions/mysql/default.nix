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
  phpFamily = (import ../.. { inherit pkgs tvp; }).recipes.php;
  releases = pkgs.lib.filterAttrs (
    version: _: pkgs.lib.hasPrefix "8.5." version
  ) phpFamily.versionTable;
  versionTable = tvp.lib.packages.mkTable (
    pkgs.lib.mapAttrsToList (version: release: {
      def = {
        builder = ./build.nix;
        deps.php = tvp.lib.packages.withConstraint {
          reason = "The bundled ${name} module uses the exact PHP release's source and installed SDK.";
        } tvp.packages.${tvp.lib.versions.attrName "php" version};
        opts.phpCompatibility.exact = version;
      };
      releases.${version} = release.sha256;
    }) releases
  );
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
    source = phpFamily.source;
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
