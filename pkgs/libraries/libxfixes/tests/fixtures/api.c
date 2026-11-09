#include <X11/extensions/Xfixes.h>
#include <stdio.h>
int main(void) {
  if (XFixesVersion() != XFIXES_VERSION) return 1;
  XFixesCursorImage image = {0};
  image.width = 2; image.height = 3;
  if (image.width * image.height != 6 || XFixesDisplayCursorNotifyMask == 0) return 2;
  puts("api-ok"); return 0;
}
