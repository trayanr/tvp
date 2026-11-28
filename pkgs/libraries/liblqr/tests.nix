{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ] ++ package.specification.environment.libraries;
  tests = {
    resize = {
      script = ''
        cat > resize.c <<'C'
        #include <lqr.h>

        int main(void) {
          guchar *input = g_new(guchar, 8 * 8 * 3);
          for (int i = 0; i < 8 * 8 * 3; ++i)
            input[i] = i % 256;
          LqrCarver *carver = lqr_carver_new(input, 8, 8, 3);
          if (carver == NULL)
            return 1;
          gboolean valid = lqr_carver_init(carver, 1, 0) == LQR_OK
                           && lqr_carver_resize(carver, 6, 5) == LQR_OK
                           && lqr_carver_get_width(carver) == 6
                           && lqr_carver_get_height(carver) == 5;
          lqr_carver_destroy(carver);
          return !valid;
        }
        C
        "$CC" $(pkg-config --cflags lqr-1) resize.c -o resize $(pkg-config --libs lqr-1)
        env -i ./resize
        printf lqr-resize-ok
      '';
      expected = "lqr-resize-ok";
    };
    version = {
      script = "pkg-config --modversion lqr-1";
      expected = package.version;
    };
  };
}
