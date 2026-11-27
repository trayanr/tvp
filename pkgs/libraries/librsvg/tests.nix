{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    version = {
      script = "pkg-config --modversion librsvg-2.0";
      expected = package.version;
    };
    render = {
      script = ''
        cat > rectangle.svg <<'SVG'
        <svg xmlns="http://www.w3.org/2000/svg" width="8" height="8">
          <rect width="8" height="8" fill="red"/>
        </svg>
        SVG
        env -i ${package}/bin/rsvg-convert --output=rectangle.png rectangle.svg

        cat > check.c <<'C'
        #include <cairo.h>
        #include <stdint.h>

        int main(void) {
          cairo_surface_t *image = cairo_image_surface_create_from_png("rectangle.png");
          if (cairo_surface_status(image) != CAIRO_STATUS_SUCCESS ||
              cairo_image_surface_get_width(image) != 8 ||
              cairo_image_surface_get_height(image) != 8)
            return 1;
          cairo_surface_flush(image);
          int wrong = *(const uint32_t *) cairo_image_surface_get_data(image) != 0xffff0000;
          cairo_surface_destroy(image);
          return wrong;
        }
        C
        "$CC" $(pkg-config --cflags cairo) check.c -o check $(pkg-config --libs cairo)
        env -i ./check
        printf 'svg-render-ok'
      '';
      expected = "svg-render-ok";
    };
  };
}
