#define _GNU_SOURCE
#include <sys/acl.h>
#include <acl/libacl.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <stdio.h>
static void equal(acl_t expected, acl_t actual) {
    assert(actual && acl_cmp(expected, actual) == 0); acl_free(actual);
}
int main(void) {
    acl_t a = acl_from_text("u::rw-,u:12345:r--,g::r--,m::r--,o::---");
    assert(a && acl_valid(a) == 0);
    int f = open("file", O_CREAT|O_RDWR|O_EXCL, 0600);
    assert(f >= 0);
    if (acl_set_fd(f, a) < 0) {
        if (errno == ENOTSUP || errno == EOPNOTSUPP) {
            fprintf(stderr, "SKIP native: filesystem rejects named ACLs (errno=%d)\n", errno);
            return 77;
        }
        perror("acl_set_fd"); return 1;
    }
    equal(a, acl_get_fd(f));
    assert(acl_extended_fd(f) == 1 && acl_extended_file("file") == 1);
    assert(mkdir("dir", 0700) == 0);
    assert(acl_set_file("dir", ACL_TYPE_DEFAULT, a) == 0);
    equal(a, acl_get_file("dir", ACL_TYPE_DEFAULT));
    int child = open("dir/child", O_CREAT|O_RDWR|O_EXCL, 0660);
    assert(child >= 0); equal(a, acl_get_fd(child));
    assert(acl_delete_def_file("dir") == 0);
    acl_t empty = acl_get_file("dir", ACL_TYPE_DEFAULT);
    assert(empty && acl_entries(empty) == 0); acl_free(empty);
    int dest = open("copy", O_CREAT|O_RDWR|O_EXCL, 0600);
    assert(dest >= 0 && perm_copy_file("file", "copy", NULL) == 0);
    equal(a, acl_get_fd(dest));
    assert(perm_copy_fd("file", f, "copy", dest, NULL) == 0);
    equal(a, acl_get_fd(dest));
    close(f); close(child); close(dest); acl_free(a);
    fprintf(stderr, "PASS native: named access/default, copy, directory inheritance\n");
    return 0;
}
