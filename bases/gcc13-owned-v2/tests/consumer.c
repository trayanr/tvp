#include <dlfcn.h>
#include <stdio.h>
int main(void) {
    void *library = dlopen("liboptional.so", RTLD_NOW);
    if (!library) { fprintf(stderr, "%s\n", dlerror()); return 1; }
    int (*answer)(void) = (int (*)(void))dlsym(library, "answer");
    if (!answer || answer() != 42) return 2;
    printf("%d\n", answer());
    return dlclose(library);
}
