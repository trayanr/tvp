{ package }:
let
  p = package;
  d = p.specification;
in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.pkgConfig
    d.binutils
    d.bzip2
    package.tvp.declaredTestDependencies.gzip
  ];
  libraries = [ p ];
  tests = {
    consumer = {
      script = ''
        cc $(pkg-config --cflags freetype2) ${./fixtures/consumer.c} $(pkg-config --libs freetype2) -o consumer
        ./consumer ${./fixtures/font.bdf}
      '';
      expected = p.version;
    };
    compressed-static = {
      script = ''
        cc $(pkg-config --cflags freetype2) ${./fixtures/consumer.c} ${p}/lib/libfreetype.a ${d.zlib}/lib/libz.a ${d.bzip2}/lib/libbz2.a -lm -o consumer
        gzip -c ${./fixtures/font.bdf} > font.bdf.gz
        bzip2 -c ${./fixtures/font.bdf} > font.bdf.bz2
        ./consumer ${./fixtures/font.bdf}
        cc $(pkg-config --cflags freetype2) ${./fixtures/compressed-stream.c} ${p}/lib/libfreetype.a ${d.zlib}/lib/libz.a ${d.bzip2}/lib/libbz2.a -lm -o compressed-stream
        ./compressed-stream gzip font.bdf.gz ${./fixtures/font.bdf}
        ./compressed-stream bzip2 font.bdf.bz2 ${./fixtures/font.bdf}
      '';
      expected = "${p.version}\ncompressed-stream-roundtrip\ncompressed-stream-roundtrip";
    };
    discovery-profile = {
      script = ''
        test "$(pkg-config --modversion freetype2)" = 26.7.20
        readelf -d ${p}/lib/libfreetype.so > dynamic
        grep -F libz.so dynamic >/dev/null
        grep -F libbz2.so dynamic >/dev/null
        if grep -E 'lib(png|brotli|harfbuzz)' dynamic; then exit 1; fi
        printf '%s\n' compressed-font-profile
      '';
      tools = [
        d.pkgConfig
        d.binutils
        d.grep
      ];
      expected = "compressed-font-profile";
    };
  };
}
