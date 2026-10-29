#include <X11/extensions/Xrandr.h>
#include <stdio.h>
int main(void) { XRRCrtcGamma *g=XRRAllocGamma(3);if(!g || g->size!=3) return 1;g->red[2]=65535;XRRFreeGamma(g);puts("loaded");return 0; }
