#include <X11/Xdmcp.h>
#include <stdio.h>
int main(void) { unsigned char data[64]; XdmcpBuffer b={data,64,0,0}; CARD32 result=0; if(!XdmcpWriteCARD32(&b,0x12345678)) return 1; b.count=b.pointer; b.pointer=0; if(!XdmcpReadCARD32(&b,&result)||result!=0x12345678) return 2; puts("api-ok"); }
