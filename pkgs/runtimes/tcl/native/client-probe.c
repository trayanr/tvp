/* Independent capability probe; never substitutes for the Tcl driver fixture. */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (library) { dlclose(library); return 0; }
    const char *error = dlerror();
    char expected[512];
    int length = snprintf(expected, sizeof expected,
        "%s: cannot open shared object file: No such file or directory", argv[1]);
    if (length < 0 || length >= sizeof expected) return 2;
    if (error && !strcmp(error, expected)) return 77;
    fprintf(stderr, "%s\n", error ? error : "dlopen failed without a diagnostic");
    return 1;
}
