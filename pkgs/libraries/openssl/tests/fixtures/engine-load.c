#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc != 2) return 1;
    void *engine = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!engine) { fprintf(stderr, "%s\n", dlerror()); return 2; }
    if (!dlsym(engine, "bind_engine")) return 3;
    return dlclose(engine) != 0;
}
