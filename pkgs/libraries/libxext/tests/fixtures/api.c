#include <X11/Xlib.h>
#include <X11/Xproto.h>
/* extutil.h exposes C ABI declarations without its own C++ linkage guard. */
#ifdef __cplusplus
extern "C" {
#endif
#include <X11/extensions/extutil.h>
#ifdef __cplusplus
}
#endif
#include <X11/extensions/shape.h>
#include <stdio.h>
int main(void) {
  XExtensionInfo *info = XextCreateExtension();
  if (!info || info->ndisplays != 0 || info->head != NULL) return 1;
  XextDestroyExtension(info);
  if (ShapeBounding != 0 || ShapeInput != 2) return 2;
  puts("api-ok"); return 0;
}
