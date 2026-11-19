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
      script = ''${runtime}/bin/php -r 'echo phpversion("sodium");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          echo sodium_bin2hex(sodium_crypto_generichash("tvp-sodium-fixture", "", 32));
        '
      '';
      expected = "5ded2e0d20c6540321c1a209b490ff8539e96ed267b1800f40e0e54bbf502f49";
    };
  };
}
