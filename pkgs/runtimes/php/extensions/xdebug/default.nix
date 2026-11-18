{ pkgs, tvp }:
let
  pname = "php-xdebug";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.packages.php_8_3;
          zlib = tvp.packages.zlib;
        };
        phpRequirements = {
          min = "8.0.0";
          max = "8.3.99";
          reason = "Xdebug 3.3.2 declares PHP 8.0 through 8.3 in package.xml.";
          source = "https://pecl.php.net/get/xdebug-3.3.2.tgz";
        };
        opts.phpCompatibility = {
          min = "8.2";
          before = "8.4";
        };
        patches = [
          {
            file = ./c23-develop-minit.patch;
            reason = "Backport the module initialization prototype from upstream commit eae1b06aeb67 for C23.";
          }
        ];
      };
      releases."3.3.2" = "sha256-FVRbgxG+21598I/ZDWZT2b8zYpeR6BGecDUEdd+TLFU=";
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          php = tvp.packages.php_8_5;
          zlib = tvp.packages.zlib;
        };
        phpRequirements = {
          min = "8.0.0";
          max = "8.5.99";
          reason = "Xdebug 3.5.3 declares PHP 8.0 through 8.5 in package.xml.";
          source = "https://pecl.php.net/get/xdebug-3.5.3.tgz";
        };
        opts.phpCompatibility = {
          min = "8.2";
          before = "8.6";
        };
      };
      releases."3.5.3" = "sha256-8HPekb6gRhBqv01gcclj6nHlhXHfbOWJSM7KidEhyy0=";
    }
  ];
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp versionTable;
    name = "xdebug";
    source = tvp.lib.sources.archive {
      url = version: "https://pecl.php.net/get/xdebug-${version}.tgz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/xdebug/xdebug.git";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP debugger and profiler";
      homepage = "https://xdebug.org/";
      license = {
        spdxId = "Xdebug-1.03";
        fullName = "Xdebug License 1.03";
        url = "https://xdebug.org/license/1.03";
        free = true;
      };
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
