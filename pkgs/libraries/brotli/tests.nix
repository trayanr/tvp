{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    roundtrip = {
      tools = [ tools.diffutils ];
      script = ''
        printf '%s\n' 'Brotli compression round trip' > original
        brotli -o encoded.br original
        brotli -d -o decoded encoded.br
        cmp original decoded
        printf '%s\n' 'round trip'
      '';
      expected = "round trip";
    };
    consumer = {
      tools = [ tools.pkg-config ];
      script = ''
        for lib in libbrotlicommon libbrotlidec libbrotlienc; do
          test "$(pkg-config --modversion "$lib")" = "${package.version}"
        done
        "$CC" ${./consumer.c} $(pkg-config --cflags --libs libbrotlienc libbrotlidec) -o consumer
        ./consumer
      '';
      expected = "Brotli C API";
    };
    archives = {
      script = ''
        "$CC" -I"${package}/include" ${./consumer.c} \
          "${package}/lib/libbrotlienc-static.a" "${package}/lib/libbrotlidec-static.a" \
          "${package}/lib/libbrotlicommon-static.a" -lm -o consumer
        ./consumer
      '';
      expected = "Brotli C API";
    };
  };
}
