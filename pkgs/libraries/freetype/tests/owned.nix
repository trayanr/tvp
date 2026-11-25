{
  package,
  lib,
  context,
}:
let
  tools = (package.specification.base.tools or { }) // {
    binutils = package.specification.base.compiler.bintools;
  };
  p = package;
  d = p.specification;
  withPng = p.tvp.features.png;
  # The TVP libpng provider installs a shared library.
  staticLink = ''
    ${p}/lib/libfreetype.a ${lib.optionalString withPng "-L${d.png}/lib -Wl,-rpath,${d.png}/lib -lpng"} \
      ${d.zlib}/lib/libz.a ${d.bzip2}/lib/libbz2.a -lm
  '';
  profile = if withPng then "compressed-font-and-png-profile" else "compressed-font-profile";
in
context.mkSuite {
  inherit package;
  tools = [
    d.pkg-config
    tools.binutils
    d.bzip2
    tools.gzip
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
        cc $(pkg-config --cflags freetype2) ${./fixtures/consumer.c} -o consumer ${staticLink}
        gzip -c ${./fixtures/font.bdf} > font.bdf.gz
        bzip2 -c ${./fixtures/font.bdf} > font.bdf.bz2
        ./consumer ${./fixtures/font.bdf}
        cc $(pkg-config --cflags freetype2) ${./fixtures/compressed-stream.c} -o compressed-stream ${staticLink}
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
        if grep -E 'lib(brotli|harfbuzz)' dynamic; then exit 1; fi
        ${
          if withPng then
            ''
              grep -F libpng16.so dynamic >/dev/null
              grep '^#define FT_CONFIG_OPTION_USE_PNG' \
                ${p}/include/freetype2/freetype/config/ftoption.h >/dev/null
            ''
          else
            ''
              if grep -F libpng16.so dynamic; then exit 1; fi
            ''
        }
        printf '%s\n' ${profile}
      '';
      tools = [
        d.pkg-config
        tools.binutils
        tools.grep
      ];
      expected = profile;
    };
  };
}
