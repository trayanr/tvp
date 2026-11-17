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
    settings.memory_limit = "128M";
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("igbinary");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $value = array(
            "binary" => "tvp\0igbinary",
            "nested" => array(null, true, false, 42, 1.5, "42"),
            "empty" => array()
          );
          $encoded = igbinary_serialize($value);
          if (!is_string($encoded) || igbinary_unserialize($encoded) !== $value) {
            exit(1);
          }
          echo "igbinary-roundtrip";
        '
      '';
      expected = "igbinary-roundtrip";
    };
  };
}
