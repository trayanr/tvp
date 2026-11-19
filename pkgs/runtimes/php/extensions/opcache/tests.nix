{
  tvp,
  builtIn ? false,
}:
{
  package,
  lib,
  context,
}:
let
  php = if builtIn then package else package.php;
  runtime = import ../../with-extensions.nix {
    inherit lib tvp php;
    extensions = lib.optional (!builtIn) package;
    settings = {
      "opcache.enable_cli" = true;
      "opcache.file_update_protection" = 0;
    };
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''
        ${if builtIn then "${php}/bin/php -n" else "${runtime}/bin/php"} -r '
          $count = count(array_keys(get_loaded_extensions(true), "Zend OPcache", true));
          if ($count !== 1 || !function_exists("opcache_get_status")) {
            throw new RuntimeException("Expected one loaded Zend OPcache");
          }
          echo phpversion("Zend OPcache");
        '
      '';
      expected = php.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $fixture = __DIR__ . "/fixture.php";
          file_put_contents($fixture, "<?php return 6 * 7;");
          if (!opcache_compile_file($fixture) || !opcache_is_script_cached($fixture)) {
            throw new RuntimeException("OPcache did not cache the fixture");
          }
          echo require $fixture;
        '
      '';
      expected = "42";
    };
  };
}
