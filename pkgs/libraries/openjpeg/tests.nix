{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.pkg-config
    tools.diffutils
  ];
  libraries = [ package ];
  tests = {
    pkg-config = {
      script = "pkg-config --modversion libopenjp2";
      expected = package.version;
    };
    codec = {
      script = ''
        printf 'P5\n2 2\n255\n\000\017\162\377' > original.pgm
        opj_compress -n 1 -i original.pgm -o coded.jp2 >&2
        opj_decompress -i coded.jp2 -o decoded.pgm >&2
        test "$(head -c 2 decoded.pgm)" = P5
        tail -c 4 decoded.pgm > actual
        tail -c 4 original.pgm > expected
        cmp actual expected
        printf '%s\n' 'JPEG 2000'
      '';
      expected = "JPEG 2000";
    };
  };
}
