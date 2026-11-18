{ pkgs, tvp, ... }:
let
  pname = "php-apcu";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        deps.php = tvp.packages.php_8_5;
        opts = {
          # PECL declares PHP 7.0 as the minimum. TVP currently packages through 8.5.
          phpCompatibility = {
            min = "7.0";
            before = "8.6";
          };
          configureOptions = [
            "--enable-apcu"
            "--disable-valgrind-checks"
          ];
        };
      };
      releases."5.1.28" = "sha256-ypwYIIEKFoeG+ASKTD+Mnj/ZQUB60VUyWfsuMLXwV78=";
    }
  ];
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp versionTable;
    name = "apcu";
    source = tvp.lib.sources.archive {
      url = version: "https://pecl.php.net/get/apcu-${version}.tgz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/krakjoe/apcu.git";
        prefix = "v";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "APCu in-memory user cache for PHP";
      homepage = "https://www.php.net/manual/en/book.apcu.php";
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
