{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    version = {
      script = "pkg-config --modversion pixman-1";
      expected = package.version;
    };
    composite = {
      script = ''
        cat > composite.c <<'C'
        #include <pixman.h>
        #include <stdint.h>

        int main(void) {
          uint32_t source = 0xff804020;
          uint32_t result = 0;
          pixman_image_t *from = pixman_image_create_bits(PIXMAN_a8r8g8b8, 1, 1, &source, 4);
          pixman_image_t *to = pixman_image_create_bits(PIXMAN_a8r8g8b8, 1, 1, &result, 4);
          if (!from || !to)
            return 1;
          pixman_image_composite32(PIXMAN_OP_SRC, from, NULL, to, 0, 0, 0, 0, 0, 0, 1, 1);
          pixman_image_unref(from);
          pixman_image_unref(to);
          return result != source;
        }
        C
        "$CC" $(pkg-config --cflags pixman-1) composite.c -o composite $(pkg-config --libs pixman-1)
        env -i ./composite
        printf 'pixels-ok'
      '';
      expected = "pixels-ok";
    };
  };
}
