#define _GNU_SOURCE
#include <attr/attributes.h>
#include <attr/libattr.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/xattr.h>
#include <unistd.h>

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "line %d: %s (errno %d)\n", __LINE__, #x, errno); return 1; } } while (0)

static int policy(const char *name, struct error_context *ctx) {
    return strcmp(name, "user.skip") && attr_copy_check_permissions(name, ctx);
}

int main(int argc, char **argv) {
    Dl_info info;
    char actual[4096], expected[4096], value[32], names[4096];
    attrlist_cursor_t cursor = {{0}};
    int src, dst, length = sizeof(value), found = 0;
    CHECK(argc == 2 || argc == 3);
    CHECK(dladdr((void *)attr_copy_file, &info));
    CHECK(realpath(info.dli_fname, actual));
    CHECK(realpath(argv[1], expected));
    CHECK(!strcmp(actual, expected));
    if (argc == 3 && !strcmp(argv[2], "--linkage-only")) {
        CHECK(attr_copy_action("user.keep", NULL) == 0);
        CHECK(attr_copy_action("system.posix_acl_access", NULL) == ATTR_ACTION_PERMISSIONS);
        puts("ok");
        return 0;
    }
    src = open("source", O_CREAT | O_EXCL | O_RDWR, 0600);
    dst = open("destination", O_CREAT | O_EXCL | O_RDWR, 0600);
    CHECK(src >= 0 && dst >= 0);
    CHECK(attr_set("source", "keep", "value", 5, ATTR_CREATE) == 0);
    CHECK(attr_set("source", "keep", "bad", 3, ATTR_CREATE) == -1 && errno == EEXIST);
    CHECK(attr_getf(src, "keep", value, &length, 0) == 0);
    CHECK(length == 5 && !memcmp(value, "value", 5));
    CHECK(attr_list("source", names, sizeof(names), 0, &cursor) == 0);
    CHECK(!((attrlist_t *)names)->al_more);
    for (int i = 0; i < ((attrlist_t *)names)->al_count; i++) {
        attrlist_ent_t *entry = ATTR_ENTRY(names, i);
        if (!strcmp(entry->a_name, "keep") && entry->a_valuelen == 5) found++;
    }
    CHECK(found == 1);
    CHECK(attr_setf(src, "skip", "private", 7, 0) == 0);
    CHECK(attr_copy_action("user.keep", NULL) == 0);
    CHECK(attr_copy_action("system.posix_acl_access", NULL) == ATTR_ACTION_PERMISSIONS);
    CHECK(!attr_copy_check_permissions("system.posix_acl_access", NULL));
    CHECK(attr_copy_file("source", "destination", policy, NULL) == 0);
    CHECK(getxattr("destination", "user.keep", value, sizeof(value)) == 5);
    CHECK(!memcmp(value, "value", 5));
    CHECK(getxattr("destination", "user.skip", value, sizeof(value)) == -1 && errno == ENODATA);
    CHECK(attr_removef(dst, "keep", 0) == 0);
    CHECK(attr_copy_fd("source", src, "destination", dst, NULL, NULL) == 0);
    CHECK(getxattr("destination", "user.keep", value, sizeof(value)) == 5);
    CHECK(getxattr("destination", "user.skip", value, sizeof(value)) == 7);
    CHECK(attr_remove("source", "keep", 0) == 0);
    CHECK(attr_get("source", "keep", value, &length, 0) == -1 && errno == ENODATA);
    CHECK(close(src) == 0 && close(dst) == 0);
    puts("ok");
    return 0;
}
