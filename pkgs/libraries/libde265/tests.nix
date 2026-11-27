{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [
    package.specification.base.tools.pkg-config
    package.specification.base.tools.grep
  ];
  libraries = [ package ];
  tests = {
    decoder-api = {
      script = ''
        cat > decoder.c <<'C'
        #include <stdio.h>
        #include <libde265/de265.h>
        int main(void) {
          de265_decoder_context *ctx = de265_new_decoder();
          if (ctx == NULL || de265_free_decoder(ctx) != DE265_OK) return 1;
          puts(de265_get_version());
          return 0;
        }
        C
        "$CC" $(pkg-config --cflags libde265) decoder.c -o decoder $(pkg-config --libs libde265)
        env -i ./decoder
      '';
      expected = package.version;
    };
    command = {
      script = ''
        dec265 --help > help 2>&1
        grep -Fiq 'usage' help
        printf 'dec265-ok'
      '';
      expected = "dec265-ok";
    };
  };
}
