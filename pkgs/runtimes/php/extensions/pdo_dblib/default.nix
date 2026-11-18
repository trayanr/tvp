{ pkgs, tvp, ... }:
let
  phpFamily = (import ../.. { inherit pkgs tvp; }).recipes.php;
  releases = pkgs.lib.filterAttrs (
    version: _: pkgs.lib.hasPrefix "8.5." version
  ) phpFamily.versionTable;
  versionTable = tvp.lib.packages.mkTable (
    pkgs.lib.mapAttrsToList (version: release: {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.lib.packages.withConstraint {
            reason = "Bundled PDO_DBLIB uses the exact PHP release's source and installed SDK.";
          } tvp.packages.${tvp.lib.versions.attrName "php" version};
          freetds = tvp.packages.freetds_1;
        };
        opts.phpCompatibility.exact = version;
      };
      releases.${version} = release.sha256;
    }) releases
  );
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp versionTable;
    name = "pdo_dblib";
    source = phpFamily.source;
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP PDO driver for Sybase and Microsoft SQL Server via FreeTDS";
      homepage = "https://www.php.net/manual/en/ref.pdo-dblib.php";
      license = pkgs.lib.licenses.php301;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.php-pdo_dblib = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases {
    pname = "php-pdo_dblib";
    inherit versionTable canonical;
  };
}
