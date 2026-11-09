#include <xcb/xcb.h>
#include <xcb/xcbext.h>
#include <xcb/xproto.h>
#include <xcb/render.h>
#include <xcb/xinput.h>
// xcb-proto 1.17 generates C fields named explicit in xkb.h.
// Retain full XKB C coverage; the C++ subset uses the other public headers.
#ifndef __cplusplus
#include <xcb/xkb.h>
#endif
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
int main(void) { char *h=0; int d=-1,s=-1; if(!xcb_parse_display("tvp.invalid:7.2",&h,&d,&s)||strcmp(h,"tvp.invalid")||d!=7||s!=2) return 1; free(h); if(!xcb_render_id.name || !xcb_input_id.name) return 2; 
#ifndef __cplusplus
if(!xcb_xkb_id.name) return 3;
#endif
puts("api-ok"); }
