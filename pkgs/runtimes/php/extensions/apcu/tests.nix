{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
    settings."apc.enable_cli" = true;
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("apcu");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $key = "tvp-apcu-smoke";
          $value = ["answer" => 42, "flag" => false];
          if (!apcu_enabled() || !apcu_store($key, $value)) {
            throw new RuntimeException("APCu could not store the value");
          }
          if (apcu_fetch($key, $found) !== $value || !$found) {
            throw new RuntimeException("APCu did not return the stored value");
          }
          if (!apcu_delete($key) || apcu_exists($key)) {
            throw new RuntimeException("APCu could not remove the key");
          }
          echo "apcu-roundtrip";
        '
      '';
      expected = "apcu-roundtrip";
    };
  };
}
