{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ] ++ package.specification.environment.libraries;
  tests = {
    version = {
      script = "pkg-config --modversion cairo";
      expected = package.version;
    };
    png = {
      script = ''
        cat > draw.c <<'C'
        #include <cairo.h>
        #include <stdint.h>

        int main(void) {
          cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 8, 8);
          cairo_t *canvas = cairo_create(surface);
          cairo_set_source_rgb(canvas, 1, 0, 0);
          cairo_paint(canvas);
          if (cairo_surface_write_to_png(surface, "red.png") != CAIRO_STATUS_SUCCESS)
            return 1;
          cairo_destroy(canvas);
          cairo_surface_destroy(surface);

          surface = cairo_image_surface_create_from_png("red.png");
          if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS ||
              cairo_image_surface_get_width(surface) != 8 ||
              cairo_image_surface_get_height(surface) != 8)
            return 1;
          cairo_surface_flush(surface);
          int wrong = *(const uint32_t *) cairo_image_surface_get_data(surface) != 0xffff0000;
          cairo_surface_destroy(surface);
          return wrong;
        }
        C
        "$CC" $(pkg-config --cflags cairo) draw.c -o draw $(pkg-config --libs cairo)
        env -i ./draw
        printf 'cairo-png-ok'
      '';
      expected = "cairo-png-ok";
    };
  };
}
