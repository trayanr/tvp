#include <stdio.h>
#include <stdint.h>
#include <mpdecimal.h>
int main(void) {
    mpd_context_t ctx;
    mpd_defaultcontext(&ctx);
    uint32_t status = 0;
    mpd_t *a = mpd_new(&ctx), *b = mpd_new(&ctx), *c = mpd_new(&ctx);
    if (!a || !b || !c) return 1;
    mpd_qset_string(a, "0.1", &ctx, &status);
    mpd_qset_string(b, "0.2", &ctx, &status);
    mpd_qadd(c, a, b, &ctx, &status);
    char *s = mpd_to_sci(c, 1);
    if (status || !s) return 1;
    printf("%s", s);
    mpd_free(s); mpd_del(a); mpd_del(b); mpd_del(c);
    return 0;
}
