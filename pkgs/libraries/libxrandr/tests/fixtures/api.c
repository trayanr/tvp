#include <X11/extensions/Xrandr.h>
#include <stdio.h>
int main(void) {
  XRRCrtcGamma *g = XRRAllocGamma(256);
  if (!g || g->size != 256 || !g->red || !g->green || !g->blue) return 1;
  for (int i=0; i<g->size; ++i) { g->red[i]=i*257; g->green[i]=65535-i*257; g->blue[i]=i*128; }
  if (g->red[255] != 65535 || g->green[255] != 0 || g->blue[255] != 32640) return 2;
  XRRFreeGamma(g);
  puts("api-ok"); return 0;
}
