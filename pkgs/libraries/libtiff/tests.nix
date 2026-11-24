{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config ];
  libraries = [ package ];
  tests = {
    pkg-config = {
      script = "pkg-config --modversion libtiff-4";
      expected = package.version;
    };
    codecs = {
      script = ''
        cat > codecs.c <<'EOF'
        #include <tiffio.h>
        #include <stdio.h>
        int main(void) {
          if (!TIFFIsCODECConfigured(COMPRESSION_JPEG)
              || !TIFFIsCODECConfigured(COMPRESSION_ADOBE_DEFLATE)
              || !TIFFIsCODECConfigured(COMPRESSION_LZMA)
              || !TIFFIsCODECConfigured(COMPRESSION_ZSTD)
              || !TIFFIsCODECConfigured(COMPRESSION_WEBP))
            return 1;
          puts("codecs");
          return 0;
        }
        EOF
        cc $(pkg-config --cflags libtiff-4) codecs.c $(pkg-config --libs libtiff-4) -o codecs
        ./codecs
      '';
      expected = "codecs";
    };
  };
}
