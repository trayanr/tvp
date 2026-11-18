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
    settings."xdebug.mode" = "develop";
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("xdebug");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          function smoke_stack() {
            return array_column(xdebug_get_function_stack(), "function");
          }
          if (!in_array("smoke_stack", smoke_stack(), true)) {
            throw new RuntimeException("Xdebug did not report the function frame");
          }
          echo "xdebug-stack-ready";
        '
      '';
      expected = "xdebug-stack-ready";
    };
  };
}
