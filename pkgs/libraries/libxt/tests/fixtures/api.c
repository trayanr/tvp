#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <stdio.h>
#include <string.h>
static int fired;
static void timeout(XtPointer data, XtIntervalId *id) { (void)id; ++*(int *)data; }
int main(void) {
  XtToolkitInitialize();
  XtAppContext app = XtCreateApplicationContext();
  if (!app) return 1;
  char *value = XtNewString("owned-xt");
  if (!value || strcmp(value,"owned-xt")) return 2;
  XtFree(value);
  XtAppAddTimeOut(app,0,timeout,&fired);
  XtAppProcessEvent(app,XtIMTimer);
  if (fired != 1) return 3;
  XtDestroyApplicationContext(app);
  puts("api-ok"); return 0;
}
