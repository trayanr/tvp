#define _GNU_SOURCE
#include <dlfcn.h>
#include <gmp.h>
#include <isl/version.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void check(void *symbol, const char *expected) {
    Dl_info info;
    char actual[PATH_MAX], wanted[PATH_MAX];
    if (!dladdr(symbol, &info) || !realpath(info.dli_fname, actual) ||
        !realpath(expected, wanted) || strcmp(actual, wanted)) {
        fprintf(stderr, "FAIL loaded library, expected %s\n", expected);
        exit(1);
    }
    printf("PASS loaded %s\n", actual);
}
int main(int argc, char **argv) {
    if (argc != 4) return 1;
    check((void *)isl_version, argv[1]);
    check((void *)__gmpz_init, argv[2]);
    if (strcmp(gmp_version, "6.3.0") ||
        __GNU_MP_VERSION != 6 || __GNU_MP_VERSION_MINOR != 3 || __GNU_MP_VERSION_PATCHLEVEL != 0)
        return 1;
    char prefix[80];
    snprintf(prefix, sizeof(prefix), "isl-%s", argv[3]);
    if (strncmp(isl_version(), prefix, strlen(prefix)) ||
        (isl_version()[strlen(prefix)] != '\0' && isl_version()[strlen(prefix)] != '-')) return 1;
    puts("PASS matching ISL version and GMP 6.3.0 headers/runtime");
    return 0;
}
