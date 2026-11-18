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
      script = ''${runtime}/bin/php -r 'echo curl_version()["version"];' '';
      expected = package.specification.curl.version;
    };
    roundtrip = {
      script = ''
        printf '%s' 'php-curl-fixture' > fixture.txt
        ${runtime}/bin/php -r '
          $handle = curl_init("file://" . getcwd() . "/fixture.txt");
          curl_setopt($handle, CURLOPT_RETURNTRANSFER, true);
          $result = curl_exec($handle);
          if ($result === false) {
            throw new RuntimeException(curl_error($handle));
          }
          echo $result;
        '
      '';
      expected = "php-curl-fixture";
    };
  };
}
