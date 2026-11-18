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
      script = ''${runtime}/bin/php -r 'echo phpversion("bcmath");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          if (bcadd("0.1", "0.2", 2) !== "0.30") {
            throw new RuntimeException("BCMath did not preserve the decimal scale");
          }
          $original = "100000000000000000000.01";
          $product = bcmul($original, "9", 2);
          echo bcdiv($product, "9", 2);
        '
      '';
      expected = "100000000000000000000.01";
    };
  };
}
