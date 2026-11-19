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
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("soap");' '';
      expected = package.version;
    };
    roundtrip = {
      script = "${runtime}/bin/php ${./roundtrip.php}";
      expected = "SOAP: <&>";
    };
  };
}
