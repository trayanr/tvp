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
      script = ''${runtime}/bin/php -r 'echo phpversion("mongodb");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $value = ["answer" => 42, "flags" => [true, false]];
          $encoded = MongoDB\BSON\Document::fromPHP($value);
          $decoded = $encoded->toPHP(["root" => "array"]);
          if ($decoded !== $value) {
            throw new RuntimeException("BSON round trip changed the document");
          }
          new MongoDB\Driver\Manager("mongodb://127.0.0.1/?tls=true");
          echo "mongodb-roundtrip";
        '
      '';
      expected = "mongodb-roundtrip";
    };
  };
}
