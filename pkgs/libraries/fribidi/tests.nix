{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    bidi = {
      script = ''
        cat > bidi.c <<'C'
        #include <fribidi.h>

        int main(void) {
          FriBidiChar input[] = { 0x05d0, 0x05d1 };
          FriBidiChar visual[2];
          FriBidiParType direction = FRIBIDI_PAR_ON;
          if (!fribidi_log2vis(input, 2, &direction, visual, 0, 0, 0))
            return 1;
          return direction != FRIBIDI_PAR_RTL || visual[0] != input[1] || visual[1] != input[0];
        }
        C
        "$CC" $(pkg-config --cflags fribidi) bidi.c -o bidi $(pkg-config --libs fribidi)
        env -i ./bidi
        printf 'bidi-ok'
      '';
      expected = "bidi-ok";
    };
    version = {
      script = "pkg-config --modversion fribidi";
      expected = package.version;
    };
  };
}
