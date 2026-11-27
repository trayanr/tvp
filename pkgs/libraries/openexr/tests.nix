{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [
    package
    package.specification.imath
    package.specification.zstd
  ];
  tests = {
    api = {
      script = ''
        cat > header.c <<'C'
        #include <OpenEXR/ImfCRgbaFile.h>
        int main(void) {
          ImfHeader *header = ImfNewHeader();
          if (header == 0) return 1;
          ImfDeleteHeader(header);
          return 0;
        }
        C
        "$CC" $(pkg-config --cflags OpenEXR) header.c -o header $(pkg-config --libs OpenEXR)
        env -i ./header
        printf 'exr-api-ok'
      '';
      expected = "exr-api-ok";
    };
    version = {
      script = "pkg-config --modversion OpenEXR";
      expected = package.version;
    };
  };
}
