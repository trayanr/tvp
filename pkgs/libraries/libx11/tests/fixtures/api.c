#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/XKBlib.h>
#include <X11/keysym.h>
#include <string.h>
#include <stdio.h>
int main(void) { if(XStringToKeysym("Return")!=XK_Return || strcmp(XKeysymToString(XK_Return),"Return")) return 1; XrmInitialize(); XrmDatabase db=XrmGetStringDatabase("tvp.test: preserved\n"); char *type=0; XrmValue value; if(!db||!XrmGetResource(db,"tvp.test","Tvp.Test",&type,&value)||strcmp(value.addr,"preserved")) return 2; XrmDestroyDatabase(db); puts("api-ok"); }
