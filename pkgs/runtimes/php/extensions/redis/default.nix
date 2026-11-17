{ pkgs, tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ../build-phpize.nix;
        deps.php = tvp.packages.php_5_2;
        opts = {
          phpCompatibility = {
            min = "5.2";
            before = "6.0";
          };
          configureOptions = [ "--enable-redis" ];
        };
      };
      releases."2.2.8" = "sha256-/FM3Ut5ihI9kVwe2XLqdAVq07Zx6l4x71xClk02XsbU=";
    }
    {
      def = {
        builder = ../build-phpize.nix;
        deps.php = tvp.packages.php_7_3;
        opts = {
          # Initial TVP span follows upstream CI, below its loose 7.9.99 maximum.
          phpCompatibility = {
            min = "5.3";
            before = "7.4";
          };
          configureOptions = [ "--enable-redis" ];
        };
      };
      releases."4.3.0" = "sha256-wPBM7DSZYKhCtgkg+4pDNlbi5JTq7W5mM5fWcQKlG6I=";
    }
    {
      def = {
        builder = ../build-phpize.nix;
        deps.php = tvp.packages.php_8_2;
        opts = {
          phpCompatibility = {
            min = "7.2";
            before = "8.3";
          };
          configureOptions = [ "--enable-redis" ];
        };
      };
      releases."6.0.2" = "sha256-Aa7MsOFPiX/lbwUJvm5pkf8K1Fn5006V5FVtAmmbmgM=";
    }
    {
      def = {
        builder = ../build-phpize.nix;
        deps.php = tvp.packages.php_8_5;
        opts = {
          phpCompatibility = {
            min = "7.4";
            before = "8.6";
          };
          configureOptions = [ "--enable-redis" ];
        };
      };
      releases."6.3.0" = "sha256-DVFB9jS9HbbB3c2gU9JezyxPwcOVQw1TT9P41R3X8LU=";
    }
  ];
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp versionTable;
    name = "redis";
    source = tvp.lib.sources.archive {
      url = version: "https://pecl.php.net/get/redis-${version}.tgz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/phpredis/phpredis.git";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    testDeps.redis = tvp.packages.redis;
    meta = {
      homepage = "https://github.com/phpredis/phpredis";
      license = pkgs.lib.licenses.php301;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.php-redis = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases {
    pname = "php-redis";
    inherit versionTable canonical;
  };
}
