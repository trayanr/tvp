{
  package,
  lib,
  context,
}:
let
  inherit (package.specification.installedInterface) cli wandHeader;
  imageFormat = if package.specification.buildFeatures.png then "PNG" else "PPM";
  imageExtension = lib.toLower imageFormat;
  # These releases identify PPM by the enclosing PNM family name.
  reportsPnm = imageFormat == "PPM";
  reportedImageFormat = if reportsPnm then "PNM" else imageFormat;
  parts = lib.splitString "." package.version;
  upstreamVersion = lib.concatStringsSep "." (lib.take 3 parts) + "-" + lib.last parts;
in
context.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''
        banner=$(${cli} -version)
        case "$banner" in
          ${lib.escapeShellArg "Version: ImageMagick ${upstreamVersion} "}*) ;;
          *) printf '%s\n' "$banner" >&2; exit 1 ;;
        esac
        printf '%s' ${lib.escapeShellArg upstreamVersion}
      '';
      expected = upstreamVersion;
    };
    images = {
      script = ''
        ${cli} -size 3x2 xc:red example.${imageExtension}${lib.optionalString reportsPnm ''; case "$(head -c2 example.ppm)" in P3|P6) ;; *) exit 1 ;; esac''}
        ${cli} example.${imageExtension} example.jpg
        identify -format '%m %wx%h\n' example.${imageExtension} example.jpg
      '';
      expected = "${reportedImageFormat} 3x2\nJPEG 3x2";
    };
    wand = {
      tools = [ package.specification.base.tools.pkg-config ];
      libraries = [ package ];
      script = ''
        cat > wand.c <<'C'
        #include <${wandHeader}>
        int main(void) {
          MagickWandGenesis();
          MagickWand *wand = NewMagickWand();
          PixelWand *pixel = NewPixelWand();
          if (wand == 0 || pixel == 0 || !PixelSetColor(pixel, "red")
              || !MagickNewImage(wand, 3, 2, pixel)
              || MagickGetImageWidth(wand) != 3 || MagickGetImageHeight(wand) != 2)
            return 1;
          DestroyPixelWand(pixel);
          DestroyMagickWand(wand);
          MagickWandTerminus();
          return 0;
        }
        C
        "$CC" $(pkg-config --cflags MagickWand) wand.c -o wand $(pkg-config --libs MagickWand)
        env -i ./wand
        printf wand-ok
      '';
      expected = "wand-ok";
    };
  };
}
