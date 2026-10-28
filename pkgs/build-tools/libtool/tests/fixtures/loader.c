#include <ltdl.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 2 || lt_dlinit() != 0) return 1;
    lt_dlhandle module = lt_dlopen(argv[1]);
    if (!module) { fprintf(stderr, "%s\n", lt_dlerror()); return 2; }
    int (*answer)(void) = (int (*)(void)) lt_dlsym(module, "plugin_answer");
    if (!answer || answer() != 42) return 3;
    printf("%d\n", answer());
    return lt_dlclose(module) || lt_dlexit();
}
