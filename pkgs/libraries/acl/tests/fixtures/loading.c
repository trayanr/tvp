#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/acl.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
    assert(argc == 2);
    char *wanted = realpath(argv[1], NULL);
    void *h = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(h && wanted);
    acl_t (*from)(const char *) = dlsym(h, "acl_from_text");
    int (*valid)(acl_t) = dlsym(h, "acl_valid");
    int (*release)(void *) = dlsym(h, "acl_free");
    Dl_info info;
    assert(from && valid && release && dladdr((void *)from, &info));
    char *loaded = realpath(info.dli_fname, NULL);
    assert(loaded && strcmp(wanted, loaded) == 0);
    acl_t a = from("u::rw-,g::r--,o::---");
    assert(a && valid(a) == 0 && release(a) == 0);
    free(loaded); free(wanted); assert(dlclose(h) == 0);
    puts("ok");
}
