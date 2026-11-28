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
  // lib.optionalAttrs (buildFeatures.png && builtins.elem "xml" delegates) {
    application-formats = {
      tools = [ package.specification.base.tools.diffutils ];
      script = ''
        cat > rectangle.svg <<'SVG'
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
          <rect width="16" height="16" fill="red"/>
        </svg>
        SVG
        convert rectangle.svg raster.png
        test "$(identify -format '%m %wx%h' raster.png)" = 'PNG 16x16'
        convert raster.png variant.jpg
        test "$(identify -format '%m %wx%h' variant.jpg)" = 'JPEG 16x16'
        convert raster.png variant.bmp
        case "$(identify -format '%m %wx%h' variant.bmp)" in 'BMP 16x16'|'BMP2 16x16'|'BMP3 16x16') ;; *) exit 1 ;; esac
        convert raster.png variant.ico
        test "$(identify -format '%m %wx%h' variant.ico)" = 'ICO 16x16'
        convert -delay 8 raster.png -size 16x16 xc:blue -loop 0 animated.gif
        test "$(identify -format '%m %wx%h\n' animated.gif)" = "$(printf '%s\n' 'GIF 16x16' 'GIF 16x16')"
        ${lib.removeSuffix "\n" (
          if
            builtins.elem package.version [
              "6.9.4.7"
              "7.0.1.9"
            ]
          then
            ''
              # These readers accept the animation as a whole but treat [n] as part
              # of the filename. Decode both scenes in one invocation.
              convert animated.gif -coalesce -depth 8 +adjoin 'RGB:frame-%d.rgb'
              mv frame-0.rgb first.rgb
              mv frame-1.rgb second.rgb
            ''
          else
            ''
              convert 'animated.gif[0]' -depth 8 RGB:first.rgb
              convert 'animated.gif[1]' -depth 8 RGB:second.rgb
            ''
        )}
        test -s first.rgb && test -s second.rgb
        status=0
        cmp -s first.rgb second.rgb || status=$?
        test "$status" -eq 1
        printf 'formats-ok'
      '';
      expected = "formats-ok";
    };
  }
  // lib.optionalAttrs (delegates != [ ] || buildFeatures.openmp || buildFeatures.x11) {
    delegates = {
      tools = [
        binutils
        grep
      ];
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
  // lib.optionalAttrs (builtins.elem "fftw" delegates) {
    fourier = {
      tools = [
        binutils
        grep
        package.specification.base.tools.gawk
      ];
      script = ''
        readelf -d "${package}"/lib/libMagickCore*.so > needed
        grep -F 'Shared library: [libfftw3.so.3]' needed >&2
        ${cli} -size 8x8 gradient:black-white -colorspace Gray input.miff
        ${cli} input.miff -fft spectrum.miff
        test "$(identify -format '%wx%h\n' spectrum.miff)" = "$(printf '8x8\n8x8')"
        ${cli} spectrum.miff -ift result.miff
        test "$(identify -format '%wx%h' result.miff)" = '8x8'
        error=$(${cli} input.miff result.miff -compose difference -composite -format '%[fx:mean]' info:)
        awk -v error="$error" 'BEGIN { exit !(error ~ /^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/ && error < 0.004) }'
        printf 'fourier-ok'
      '';
      expected = "fourier-ok";
    };
  }
  // lib.optionalAttrs (builtins.elem "djvu" delegates) {
    djvu = {
      tools = [
        package.specification.djvulibre
        package.specification.base.tools.diffutils
      ];
      script = ''
        cjb2 ${../../djvulibre/tests/page.pbm} page.djvu
        ${cli} page.djvu page.miff
        test "$(identify -format '%wx%h' page.miff)" = '8x8'
        ${cli} page.miff -depth 8 gray:decoded
        ${cli} ${../../djvulibre/tests/page.pbm} -depth 8 gray:expected
        cmp decoded expected
        printf 'djvu-ok'
      '';
      expected = "djvu-ok";
    };
  }
  // lib.optionalAttrs (builtins.elem "openexr" delegates) {
    exr = {
      script = ''
        ${cli} -size 8x8 gradient:black-white -colorspace RGB input.exr
        test "$(identify -format '%m %wx%h' input.exr)" = 'EXR 8x8'
        ${cli} input.exr -format '%[fx:p{0,0}.r < p{0,7}.r ? 1 : 0]' info:
      '';
      expected = "1";
    };
  }
  // lib.optionalAttrs (builtins.elem "heic" delegates) {
    heic = {
      script = ''
        ${cli} -size 64x64 gradient:black-white -colorspace sRGB -quality 90 image.heic
        test "$(identify -format '%wx%h' image.heic)" = '64x64'
        ${cli} image.heic -format '%[fx:p{32,8}.r < p{32,56}.r ? 1 : 0]' info:
      '';
      expected = "1";
    };
  }
  // lib.optionalAttrs (builtins.elem "rsvg" delegates) {
    rsvg = {
      tools = [
        binutils
        grep
      ];
      script = ''
        readelf -d "${package}"/lib/libMagickCore*.so > needed
        grep -F 'Shared library: [librsvg-2.so.2]' needed >&2
        grep -F 'Shared library: [libcairo.so.2]' needed >&2
        cat > shape.svg <<'SVG'
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="12">
          <rect width="16" height="12" fill="blue"/>
          <rect width="8" height="12" fill="red"/>
        </svg>
        SVG
        ${cli} RSVG:shape.svg -format '%wx%h %[fx:p{2,2}.r] %[fx:p{12,2}.b]' info:
      '';
      expected = "16x12 1 1";
    };
  }
  // lib.optionalAttrs (builtins.elem "lqr" delegates) {
    liquid-rescale = {
      script = ''
        ${cli} -size 16x16 gradient:red-blue -liquid-rescale '12x10!' resized.miff
        identify -format '%wx%h %[fx:p{6,0}.r > p{6,9}.r ? 1 : 0]' resized.miff
      '';
      expected = "12x10 1";
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
