#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <stdio.h>
int main(void) { if(XStringToKeysym("Return")!=XK_Return) return 1;puts("loaded");return 0; }
