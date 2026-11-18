{ pkgs, tvp }:
let
  pname = "php-xdebug";
  builds =
    {
      php,
      release,
      before,
      max,
    }:
    {
      deps = { inherit php; };
      phpRequirements = {
        min = "8.0.0";
        inherit max;
        reason = "Xdebug ${release} declares PHP 8.0 through ${pkgs.lib.versions.majorMinor max} in package.xml.";
        source = "https://pecl.php.net/get/xdebug-${release}.tgz";
      };
      opts = {
        phpCompatibility = {
          min = "8.2";
          inherit before;
        };
        loader = "zend_extension";
        libraries = [ tvp.packages.zlib ];
        configureOptions = [ "--enable-xdebug" ];
      };
    };
  versionTable = tvp.lib.packages.mkTable [
    {
      def =
        builds {
          php = tvp.packages.php_8_3;
          release = "3.3.2";
          before = "8.4";
          max = "8.3.99";
        }
        // {
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
      def = builds {
        php = tvp.packages.php_8_5;
        release = "3.5.3";
        before = "8.6";
        max = "8.5.99";
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
