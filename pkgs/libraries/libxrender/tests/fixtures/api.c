#include <X11/extensions/Xrender.h>
#include <stdio.h>
int main(void) {
  XTransform t = {{{XDoubleToFixed(1.0),0,0},{0,XDoubleToFixed(1.0),0},{0,0,XDoubleToFixed(1.0)}}};
  XRenderColor color; char text[] = "rgba:12/34/56/ffff";
  if (!XRenderParseColor(NULL, text, &color)) return 1;
  if (color.red != 0x1212 || color.green != 0x3434 || color.blue != 0x5656 || color.alpha != 65535) return 2;
  if (XFixedToDouble(t.matrix[0][0]) != 1.0) return 3;
  puts("api-ok"); return 0;
}
