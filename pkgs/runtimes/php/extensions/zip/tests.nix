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
      script = "${runtime}/bin/php -r 'echo ZipArchive::LIBZIP_VERSION;' ";
      expected = package.specification.libzip.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          $archive = new ZipArchive();
          if ($archive->open("fixture.zip", ZipArchive::CREATE) !== true ||
              !$archive->addFromString("example.txt", "php-zip-fixture") ||
              !$archive->setCompressionName("example.txt", ZipArchive::CM_DEFLATE) ||
              !$archive->close()) {
            throw new RuntimeException("Cannot write the ZIP fixture");
          }
          if ($archive->open("fixture.zip", ZipArchive::CHECKCONS) !== true) {
            throw new RuntimeException("Cannot reopen the ZIP fixture");
          }
          echo $archive->getFromName("example.txt");
          $archive->close();
        '
      '';
      expected = "php-zip-fixture";
    };
  };
}
