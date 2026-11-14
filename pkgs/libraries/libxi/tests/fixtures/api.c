#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
  unsigned char bits[XIMaskLen(XI_LASTEVENT)] = {0};
  XIEventMask mask = {XIAllMasterDevices, sizeof(bits), bits};
  XISetMask(mask.mask, XI_Motion);
  XISetMask(mask.mask, XI_RawMotion);
  if (!XIMaskIsSet(mask.mask, XI_Motion) || !XIMaskIsSet(mask.mask, XI_RawMotion)) return 1;
  XIClearMask(mask.mask, XI_Motion);
  if (XIMaskIsSet(mask.mask, XI_Motion)) return 2;
  XIDeviceInfo *info = (XIDeviceInfo *)calloc(2, sizeof(XIDeviceInfo));
  if (!info) return 3;
  info[0].name = (char *)malloc(5);
  info[0].classes = (XIAnyClassInfo **)calloc(1, sizeof(XIAnyClassInfo *));
  if (!info[0].name || !info[0].classes) return 4;
  memcpy(info[0].name, "test", 5);
  XIFreeDeviceInfo(info);
  puts("api-ok"); return 0;
}
