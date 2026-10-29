#include <dlfcn.h>
#include <stdio.h>
int main(int argc,char **argv) {
  if(argc!=2) return 1;
  void *lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);if(!lib) { fputs(dlerror(),stderr);return 2; }
  if(!dlsym(lib,"xcb_parse_display")) return 3;
  dlclose(lib);puts("loaded");return 0;
}
