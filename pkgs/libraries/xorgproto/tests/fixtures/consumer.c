#include <X11/X.h>
#include <stdio.h>
int main(void) { printf("%d.%d\n",X_PROTOCOL,X_PROTOCOL_REVISION); return 0; }
