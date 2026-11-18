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
      script = ''${runtime}/bin/php -r 'echo phpversion("calendar");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $day = gregoriantojd(10, 11, 1970);
          if ($day !== 2440871) {
            throw new RuntimeException("Unexpected Julian day for 1970-10-11");
          }
          echo jdtogregorian($day);
        '
      '';
      expected = "10/11/1970";
    };
  };
}
