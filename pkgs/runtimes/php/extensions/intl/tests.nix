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
      script = ''${runtime}/bin/php -r 'echo phpversion("intl");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $locale = "fr_CA";
          $parts = ["language" => locale_get_primary_language($locale), "region" => locale_get_region($locale)];
          if ($parts !== ["language" => "fr", "region" => "CA"] || locale_compose($parts) !== $locale) {
            throw new RuntimeException("Locale handling failed");
          }
          if (Normalizer::normalize("e\u{0301}", Normalizer::FORM_C) !== "é") {
            throw new RuntimeException("Unicode normalization failed");
          }
          echo "intl-locale-and-normalization";
        '
      '';
      expected = "intl-locale-and-normalization";
    };
  };
}
