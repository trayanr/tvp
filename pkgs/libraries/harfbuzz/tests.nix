{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ] ++ package.specification.environment.libraries;
  tests = {
    unicode = {
      script = ''
        cat > unicode.c <<'C'
        #include <hb.h>
        #include <hb-glib.h>

        int main(void) {
          hb_unicode_funcs_t *unicode = hb_glib_get_unicode_funcs();
          return hb_unicode_script(unicode, 0x05d0) != HB_SCRIPT_HEBREW;
        }
        C
        "$CC" $(pkg-config --cflags harfbuzz glib-2.0) unicode.c -o unicode $(pkg-config --libs harfbuzz glib-2.0)
        env -i ./unicode
        printf 'unicode-ok'
      '';
      expected = "unicode-ok";
    };
    version = {
      script = "pkg-config --modversion harfbuzz";
      expected = package.version;
    };
  };
}
