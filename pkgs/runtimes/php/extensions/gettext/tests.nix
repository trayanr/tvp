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
      script = ''${runtime}/bin/php -r 'echo phpversion("gettext");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          if (setlocale(LC_MESSAGES, "C") !== "C") {
            throw new RuntimeException("Unable to set the C messages locale");
          }
          $domain = "tvp-gettext-fixture";
          if (bindtextdomain($domain, getcwd()) !== getcwd() || textdomain($domain) !== $domain) {
            throw new RuntimeException("Unable to bind the fixture domain");
          }
          echo gettext("sample"), ": ", ngettext("item", "items", 2);
        '
      '';
      expected = "sample: items";
    };
  };
}
