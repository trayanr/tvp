{ pkgs, tvp }:
let
  pname = "php-mongodb";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.packages.php_8_5;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib;
        };
        phpRequirements = {
          min = "8.1.0";
          max = "8.99.99";
          reason = "MongoDB 1.21.13 declares PHP 8.1 through 8.x in package.xml.";
          source = "https://pecl.php.net/get/mongodb-1.21.13.tgz";
        };
        patches = [
          {
            file = ./php85-interned-string.patch;
            reason = "Backport upstream #1849 to use the Zend string API available in PHP 8.5.";
          }
        ];
        opts = {
          phpCompatibility = {
            min = "8.1";
            before = "8.6";
          };
        };
      };
      releases."1.21.13" = "sha256-MX1uwk6O76dBQFACy/eIuFSa0wLGMMDHsI3URZQNpcY=";
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.packages.php_8_5;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib;
        };
        phpRequirements = {
          min = "8.1.0";
          max = "8.99.99";
          reason = "MongoDB 2.5.7 declares PHP 8.1 through 8.x in package.xml.";
          source = "https://pecl.php.net/get/mongodb-2.5.7.tgz";
        };
        opts = {
          phpCompatibility = {
            min = "8.2";
            before = "8.6";
          };
        };
      };
      releases."2.5.7" = "sha256-B4dzhW9AZrVnOPwTlQu37ha15m9yf7QdP77GBDx4/TI=";
    }
  ];
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp versionTable;
    name = "mongodb";
    source = tvp.lib.sources.archive {
      url = version: "https://pecl.php.net/get/mongodb-${version}.tgz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/mongodb/mongo-php-driver.git";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "MongoDB driver for PHP";
      homepage = "https://github.com/mongodb/mongo-php-driver";
      license = pkgs.lib.licenses.asl20;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
