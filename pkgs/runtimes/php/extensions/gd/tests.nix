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
      script = ''
        ${runtime}/bin/php -r '
          $info = gd_info();
          foreach (["PNG Support", "JPEG Support", "WebP Support", "FreeType Support"] as $feature) {
            if (($info[$feature] ?? false) !== true) {
              throw new RuntimeException("GD is missing " . $feature);
            }
          }
          echo phpversion("gd");
        '
      '';
      expected = package.version;
    };
    roundtrip = {
      script = "${runtime}/bin/php ${./roundtrip.php}";
      expected = "png jpeg webp";
    };
  };
}
