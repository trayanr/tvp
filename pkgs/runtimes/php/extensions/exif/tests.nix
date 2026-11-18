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
      script = ''${runtime}/bin/php -r 'echo phpversion("exif");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        ${runtime}/bin/php -r '
          // Little-endian TIFF with one IFD entry for ImageDescription.
          $description = "TVP EXIF fixture\0";
          $tiff = "II" . pack("vV", 42, 8)
            . pack("vvvVVV", 1, 0x010e, 2, strlen($description), 26, 0)
            . $description;
          $image = fopen("php://memory", "w+b");
          fwrite($image, $tiff);
          rewind($image);
          $metadata = exif_read_data($image, "IFD0");
          if ($metadata === false || $metadata["FileType"] !== IMAGETYPE_TIFF_II) {
            throw new RuntimeException("EXIF did not read the little-endian TIFF");
          }
          echo $metadata["ImageDescription"];
        '
      '';
      expected = "TVP EXIF fixture";
    };
  };
}
