#include <X11/ICE/ICElib.h>
#include <stdio.h>
static void handler(IceConn c, Bool swap, int major, unsigned long sequence,
                    int error_class, int severity, IcePointer values) {}
int main(void) {
    IceErrorHandler previous = IceSetErrorHandler(handler);
    if (IceSetErrorHandler(previous) != handler) return 1;
    puts("loaded"); return 0;
}
