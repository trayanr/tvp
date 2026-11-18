{ pkgs, tvp }:
let
  pname = "php-mongodb";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        deps.php = tvp.packages.php_8_5;
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
          libraries = [
            tvp.packages.openssl
            tvp.packages.zlib
          ];
          configureOptions = [
            "--enable-mongodb"
            "--with-mongodb-system-libs=no"
            "--with-mongodb-ssl=openssl"
            "--with-mongodb-zlib=system"
            "--with-mongodb-snappy=no"
            "--with-mongodb-zstd=no"
            "--with-mongodb-sasl=no"
            "--with-mongodb-client-side-encryption=no"
          ];
        };
      };
      releases."1.21.13" = "sha256-MX1uwk6O76dBQFACy/eIuFSa0wLGMMDHsI3URZQNpcY=";
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
