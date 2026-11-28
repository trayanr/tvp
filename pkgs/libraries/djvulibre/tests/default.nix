{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ];
  tests = {
    api = {
      script = ''
        cat > api.c <<'C'
        #include <libdjvu/ddjvuapi.h>
        int main(void) {
          ddjvu_context_t *context = ddjvu_context_create("tvp-test");
          if (context == 0) return 1;
          ddjvu_context_release(context);
          return 0;
        }
        C
        "$CC" $(pkg-config --cflags ddjvuapi) api.c -o api $(pkg-config --libs ddjvuapi)
        env -i ./api
        printf 'ddjvuapi-ok'
      '';
      expected = "ddjvuapi-ok";
    };
    page = {
      script = ''
        cjb2 ${./page.pbm} page.djvu
        ddjvu -format=pbm page.djvu page.pbm
        test "$(head -c2 page.pbm)" = P4
        test "$(wc -c < page.pbm)" -gt 8
        printf 'djvu-page-ok'
      '';
      expected = "djvu-page-ok";
    };
  };
}
