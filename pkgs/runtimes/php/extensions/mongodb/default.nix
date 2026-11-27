{ pkgs, tvp }:
let
  pname = "php-mongodb";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.packages.php_8_4;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib;
        };
        phpRequirements = {
          min = "7.4.0";
          max = "8.99.99";
          reason = "MongoDB 1.19.0 through 1.19.4 declare PHP 7.4 through 8.x in package.xml.";
          source = "https://pecl.php.net/get/mongodb-1.19.0.tgz";
        };
        # Upstream lists 1.19 through PHP 8.4. Its source still uses IS_INTERNED,
        # which PHP 8.5 removed.
        opts.phpCompatibility = {
          min = "7.4";
          before = "8.5";
        };
      };
      releases = {
        "1.19.0" = "sha256-K76JglGWZ26JMsh/BZWSLisbsYpvmC7l8369xEexTRA=";
        "1.19.1" = "sha256-DKTiHbNmzscSzXB3r4uk+8jfzQMJl8BSowJ0wOVGjpo=";
        "1.19.2" = "sha256-BKgsM3ENNr2lUVIvMwZ9M03SCUX022gMylSF0Q6Kpcc=";
        "1.19.3" = "sha256-qeF7Aklxt4yJZBO0ZyJETlwNAE494nFJDJ09VeNCaOk=";
        "1.19.4" = "sha256-V8Foskp9B/czZ+SxNOuRGtEXC6fSA7xHX27xuGDBZwE=";
      };
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
