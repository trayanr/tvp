#include <X11/ICE/ICElib.h>
#include <stdio.h>
static void handler(IceConn c, Bool s, int m, unsigned long q,int e,int v,IcePointer p) {}
int main(void) { IceErrorHandler old=IceSetErrorHandler(handler); if(IceSetErrorHandler(old)!=handler) return 1; puts("api-ok"); }
