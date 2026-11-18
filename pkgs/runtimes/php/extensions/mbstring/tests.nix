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
      script = ''${runtime}/bin/php -r 'echo phpversion("mbstring");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          if (mb_strlen("é猫", "UTF-8") !== 2 || mb_strtoupper("élan", "UTF-8") !== "ÉLAN") {
            throw new RuntimeException("Multibyte text handling failed");
          }
          if (!mb_regex_encoding("UTF-8") || !mb_ereg("^é.$", "é猫")) {
            throw new RuntimeException("Multibyte regex handling failed");
          }
          echo "mbstring-text-and-regex";
        '
      '';
      expected = "mbstring-text-and-regex";
    };
  };
}
