{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [
    deps.python
    deps.binutils
    deps.patchelf
  ];
  libraries = [ package ];
  tests = {
    context-errors = {
      script = ''
        cat > context.c <<'C'
        #include <mpdecimal.h>
        #include <assert.h>
        #include <string.h>
        int main(void) {
          mpd_context_t ctx; mpd_defaultcontext(&ctx); ctx.prec=3; ctx.traps=0;
          uint32_t status=0;
          mpd_t *a=mpd_new(&ctx), *b=mpd_new(&ctx), *r=mpd_new(&ctx);
          mpd_qset_string(a,"1",&ctx,&status); mpd_qset_string(b,"3",&ctx,&status);
          mpd_qdiv(r,a,b,&ctx,&status);
          char *text=mpd_to_sci(r,1);
          assert(!strcmp(text,"0.333")); mpd_free(text);
          assert((status & (MPD_Inexact|MPD_Rounded)) == (MPD_Inexact|MPD_Rounded));
          status=0; mpd_qset_string(b,"0",&ctx,&status); mpd_qdiv(r,a,b,&ctx,&status);
          assert(status & MPD_Division_by_zero); assert(mpd_isinfinite(r));
          mpd_del(a); mpd_del(b); mpd_del(r);
        }
        C
        cc context.c -lmpdec -o context
        ./context
        test ! -e ${package}/lib/libmpdec.a
        test ! -e ${package}/lib/libmpdec++.a
        printf context-ok
      '';
      expected = "context-ok";
    };
  };
}
