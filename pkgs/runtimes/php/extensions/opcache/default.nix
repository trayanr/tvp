{ pkgs, tvp }:
let
  name = "opcache";
  pname = "php-${name}";
  bundled = import ../bundled-releases.nix {
    inherit pkgs tvp;
    minPHP = "8.2";
    beforePHP = "8.5";
    def = {
      inherit source;
      builder = ../build-bundled.nix;
      deps = { };
      opts = {
        loader = "zend_extension";
        configureOptions = [ "--enable-opcache" ];
      };
    };
  };
  inherit (bundled) versionTable;
  phpSource = bundled.source;
  source = phpSource // {
    discovery = phpSource.discovery // {
      scope = "PHP 5.5 through 8.4 releases with a standalone OPcache module.";
      include =
        version:
        phpSource.discovery.include version
        && pkgs.lib.versionAtLeast version "5.5"
        && pkgs.lib.versionOlder version "8.5";
    };
  };
  family = tvp.lib.php.mkExtensionFamily {
    inherit
      tvp
      name
      versionTable
      source
      ;
    phpPolicy = {
      kind = "bundled";
      requirements = {
        min = "5.5";
        reason = "PHP first bundled Zend OPcache in PHP 5.5.";
        source = "https://www.php.net/releases/5_5_0.php";
      };
      builtIn = {
        min = "8.5";
        reason = "PHP 8.5 always builds and loads OPcache in the engine.";
        source = "https://www.php.net/opcache.installation";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP Zend OPcache bytecode cache";
      homepage = "https://www.php.net/opcache";
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
