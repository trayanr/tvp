{
  package,
  lib,
  context,
}:
let
  inherit (package.specification.installedInterface)
    cli
    delegates
    perlModuleDirectory
    wandHeader
    ;
  inherit (package.specification) buildFeatures;
  inherit (package.specification.base.tools) binutils grep;
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
          ${lib.optionalString buildFeatures.hdri "if (!((Quantum) -0.5 < 0)) return 2;"}
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
  }
  // lib.optionalAttrs (delegates != [ ] || buildFeatures.openmp || buildFeatures.x11) {
    delegates = {
      tools = [ binutils grep ];
      script = ''
        ${lib.optionalString (builtins.elem "xml" delegates) ''
          cat > shape.svg <<'SVG'
          <svg xmlns="http://www.w3.org/2000/svg" width="3" height="2">
            <rect x="0" y="0" width="3" height="2" fill="red"/>
          </svg>
          SVG
          ${cli} shape.svg shape.miff
          test "$(identify -format '%wx%h' shape.miff)" = 3x2
        ''}
        ${lib.optionalString (builtins.elem "tiff" delegates) ''
          ${cli} -size 8x8 xc:red shape.tiff
          test "$(identify -format '%m %wx%h' shape.tiff)" = 'TIFF 8x8'
        ''}
        ${lib.optionalString (builtins.elem "webp" delegates) ''
          ${cli} -size 8x8 xc:red shape.webp
          test "$(identify -format '%m %wx%h' shape.webp)" = 'WEBP 8x8'
        ''}
        ${lib.optionalString (builtins.elem "openjp2" delegates) ''
          ${cli} -size 128x128 xc:red shape.jp2
          test "$(identify -format '%m %wx%h' shape.jp2)" = 'JP2 128x128'
        ''}
        ${lib.optionalString (buildFeatures.openmp || buildFeatures.x11) ''
          readelf -d "${package}"/lib/libMagickCore*.so > needed
          ${lib.optionalString buildFeatures.openmp "grep -F 'Shared library: [libgomp.so.1]' needed >&2"}
          ${lib.optionalString buildFeatures.x11 "grep -F 'Shared library: [libX11.so.6]' needed >&2"}
        ''}
        printf delegates-ok
      '';
      expected = "delegates-ok";
    };
  }
  // lib.optionalAttrs (perlModuleDirectory != null) {
    perl = {
      tools = [ package.specification.perl ];
      script = ''
        export PERL5LIB="${package}/${perlModuleDirectory}"
        perl -MImage::Magick -e '
          my $image = Image::Magick->new(size => "3x2");
          my $error = $image->Read("xc:red");
          die $error if $error;
          die "unexpected dimensions" unless $image->Get("width") == 3 && $image->Get("height") == 2;
          print "perl-ok";
        '
      '';
      expected = "perl-ok";
    };
  };
}
