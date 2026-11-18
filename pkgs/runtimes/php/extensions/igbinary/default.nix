{ pkgs, tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        deps.php = tvp.packages.php_8_5;
        phpRequirements = {
          min = "7.0.0";
          reason = "igbinary 3.2.17RC1 declares PHP 7.0 or newer in package.xml.";
          source = "https://pecl.php.net/get/igbinary-3.2.17RC1.tgz";
        };
        opts = {
          # Upstream requires PHP 7; this release adds PHP 8.5 support.
          phpCompatibility = {
            min = "7.0";
            before = "8.6";
          };
          configureOptions = [ "--enable-igbinary" ];
        };
      };
      # Preserve the upstream RC label, rather than presenting it as 3.2.17.
      releases."3.2.17RC1" = "sha256-kdqCFEPbElKCpq6gOfJFiN0o/11x6Bh/bsxBFlvOr7w=";
    }
  ];
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp versionTable;
    name = "igbinary";
    source = tvp.lib.sources.archive {
      url = version: "https://pecl.php.net/get/igbinary-${version}.tgz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/igbinary/igbinary.git";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+(RC[0-9]+)?" version != null;
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      homepage = "https://github.com/igbinary/igbinary";
      license = pkgs.lib.licenses.bsd3;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.php-igbinary = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases {
    pname = "php-igbinary";
    inherit versionTable canonical;
  };
}
