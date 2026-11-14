#include <X11/Xauth.h>
#include <stdio.h>
int main(void) { FILE *f=tmpfile(); char name[]="tvp",data[]="cookie"; Xauth a={0,0,0,0,0,3,name,6,data}; if(!f || !XauWriteAuth(f,&a)) return 1; rewind(f); Xauth *b=XauReadAuth(f); if(!b || b->name_length!=3 || b->data_length!=6) return 2; XauDisposeAuth(b); fclose(f); puts("api-ok"); }
