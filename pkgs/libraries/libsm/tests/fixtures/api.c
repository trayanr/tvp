#include <X11/SM/SMlib.h>
#include <stdlib.h>
#include <stdio.h>
int main(void) { SmProp *p=(SmProp*)calloc(1,sizeof(SmProp)); if(!p) return 1; SmFreeProperty(p); puts("api-ok"); }
