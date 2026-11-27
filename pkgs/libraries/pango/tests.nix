{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    version = {
      script = "pkg-config --modversion pango";
      expected = package.version;
    };
    layout = {
      script = ''
        cat > layout.c <<'C'
        #include <pango/pangocairo.h>
        #include <string.h>

        int main(void) {
          PangoFontMap *map = pango_cairo_font_map_get_default();
          if (!map)
            return 1;
          PangoContext *context = pango_font_map_create_context(map);
          PangoLayout *layout = pango_layout_new(context);
          pango_layout_set_markup(layout, "<b>one</b>\ntwo", -1);
          int wrong = strcmp(pango_layout_get_text(layout), "one\ntwo") != 0 ||
            pango_layout_get_line_count(layout) != 2;
          g_object_unref(layout);
          g_object_unref(context);
          return wrong;
        }
        C
        "$CC" $(pkg-config --cflags pangocairo) layout.c -o layout $(pkg-config --libs pangocairo)
        env -i ./layout
        printf 'pango-layout-ok'
      '';
      expected = "pango-layout-ok";
    };
  };
}
