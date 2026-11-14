#include <X11/Xlib.h>
#include <X11/extensions/XTest.h>
#include <X11/extensions/record.h>
#include <stdio.h>
int main(void) {
  XRecordRange *range = XRecordAllocRange();
  if (!range || range->core_requests.first != 0 || range->device_events.last != 0) return 1;
  range->device_events.first = KeyPress; range->device_events.last = KeyRelease;
  if (range->device_events.last <= range->device_events.first) return 2;
  XFree(range);
  puts("api-ok"); return 0;
}
