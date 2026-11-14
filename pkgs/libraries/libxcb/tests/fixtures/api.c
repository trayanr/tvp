#include <xcb/xcb.h>
#include <xcb/xcbext.h>
#include <xcb/xproto.h>
#include <xcb/render.h>
#include <xcb/xinput.h>
/* xcb-proto 1.17 generates C fields named explicit in xkb.h.
 * Retain full XKB C coverage; the C++ subset uses the other public headers. */
#ifndef __cplusplus
#include <xcb/xkb.h>
#endif
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    char *host = NULL;
    int display = -1, screen = -1;
    if (!xcb_parse_display("tvp.invalid:7.2", &host, &display, &screen)
        || strcmp(host, "tvp.invalid") || display != 7 || screen != 2)
        return 1;
    free(host);
    if (!xcb_render_id.name || !xcb_input_id.name)
        return 2;
#ifndef __cplusplus
    if (!xcb_xkb_id.name)
        return 3;
#endif
    puts("api-ok");
    return 0;
}
