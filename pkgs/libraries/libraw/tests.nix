{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config tools.grep ];
  libraries = [ package ];
  tests = {
    bayer = {
      script = ''
        for library in libraw libraw_r; do
          "$CC" $(pkg-config --cflags "$library") ${./bayer.c} $(pkg-config --libs "$library") -o bayer
          ./bayer
        done
      '';
      expected = "Bayer unpack\nBayer unpack";
    };
    metadata = {
      script = ''
        for library in libraw libraw_r; do
          test "$(pkg-config --modversion "$library")" = "${package.version}"
          pkg-config --print-requires "$library" | grep -Fxq zlib
          pkg-config --libs "$library" | grep -Fq -- -fopenmp
        done
        printf '%s\n' '${package.version}'
      '';
      expected = package.version;
    };
    identify = {
      script = ''
        status=0
        raw-identify > usage || status=$?
        test "$status" -eq 1
        grep -Fq 'Usage:' usage
        printf '%s\n' 'raw-identify'
      '';
      expected = "raw-identify";
    };
  };
}
