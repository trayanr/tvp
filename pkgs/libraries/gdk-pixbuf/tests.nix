{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    version = {
      script = "pkg-config --modversion gdk-pixbuf-2.0";
      expected = package.version;
    };
    png = {
      script = ''
        cat > pixbuf.c <<'C'
        #include <gdk-pixbuf/gdk-pixbuf.h>

        int main(void) {
          GdkPixbuf *image = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, 8, 8);
          if (!image)
            return 1;
          gdk_pixbuf_fill(image, 0xff0000ff);
          if (!gdk_pixbuf_save(image, "red.png", "png", NULL, NULL))
            return 1;
          g_object_unref(image);

          image = gdk_pixbuf_new_from_file("red.png", NULL);
          if (!image || gdk_pixbuf_get_width(image) != 8 || gdk_pixbuf_get_height(image) != 8)
            return 1;
          const guchar *pixel = gdk_pixbuf_read_pixels(image);
          int wrong = pixel[0] != 255 || pixel[1] != 0 || pixel[2] != 0 || pixel[3] != 255;
          g_object_unref(image);
          return wrong;
        }
        C
        "$CC" $(pkg-config --cflags gdk-pixbuf-2.0) pixbuf.c -o pixbuf $(pkg-config --libs gdk-pixbuf-2.0)
        env -i ./pixbuf
        printf 'pixbuf-png-ok'
      '';
      expected = "pixbuf-png-ok";
    };
  };
}
