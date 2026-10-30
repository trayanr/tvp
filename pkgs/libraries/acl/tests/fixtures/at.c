#define _GNU_SOURCE
#include <sys/acl.h>
#include <acl/libacl.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <stdio.h>
static void equal(acl_t a, acl_t b) { assert(b && acl_cmp(a,b) == 0); acl_free(b); }
#define INVALID(expr) do { errno = 0; assert((expr) == -1 && errno == EINVAL); } while (0)
int main(void) {
    assert(mkdir("at-dir", 0700) == 0);
    int d = open("at-dir", O_RDONLY|O_DIRECTORY), f = openat(d,"file",O_CREAT|O_RDWR,0600);
    assert(d >= 0 && f >= 0);
    acl_t a = acl_from_text("u::rw-,u:12345:r--,g::r--,m::r--,o::---"); assert(a);
    if (acl_set_file_at(d,"file",0,ACL_TYPE_ACCESS,a) < 0) {
        if (errno == ENOTSUP || errno == EOPNOTSUPP) {
            fprintf(stderr,"SKIP at: filesystem rejects named ACLs (errno=%d)\n",errno); return 77;
        }
        perror("acl_set_file_at"); return 1;
    }
    equal(a,acl_get_file_at(d,"file",0,ACL_TYPE_ACCESS));
    equal(a,acl_get_file_at(f,"",AT_EMPTY_PATH,ACL_TYPE_ACCESS));
    assert(acl_set_file_at(f,"",AT_EMPTY_PATH,ACL_TYPE_ACCESS,a) == 0);
    assert(acl_extended_file_at(d,"file",0) == 1);
    assert(acl_extended_file_at(f,"",AT_EMPTY_PATH) == 1);
    assert(symlinkat("file",d,"link") == 0);
    equal(a,acl_get_file_at(d,"link",0,ACL_TYPE_ACCESS));
    assert(acl_extended_file_at(d,"link",0) == 1);
    assert(acl_set_file_at(d,"link",0,ACL_TYPE_ACCESS,a) == 0);
    errno=0; acl_t link = acl_get_file_at(d,"link",AT_SYMLINK_NOFOLLOW,ACL_TYPE_ACCESS);
    assert(!link && errno == EOPNOTSUPP);
    errno=0; assert(acl_set_file_at(d,"link",AT_SYMLINK_NOFOLLOW,ACL_TYPE_ACCESS,a) == -1);
    assert(errno == EOPNOTSUPP || errno == EPERM);
    errno=0; assert(acl_extended_file_at(d,"link",AT_SYMLINK_NOFOLLOW) == -1 && errno == EOPNOTSUPP);
    errno=0; assert(acl_delete_def_file_at(d,"link",AT_SYMLINK_NOFOLLOW) == -1);
    assert(errno == EOPNOTSUPP || errno == EPERM);
    assert(acl_set_file_at(d,"",AT_EMPTY_PATH,ACL_TYPE_DEFAULT,a) == 0);
    equal(a,acl_get_file_at(d,".",0,ACL_TYPE_DEFAULT));
    assert(acl_delete_def_file_at(d,".",0) == 0);
    assert(acl_set_file_at(d,".",0,ACL_TYPE_DEFAULT,a) == 0);
    assert(acl_delete_def_file_at(d,"",AT_EMPTY_PATH) == 0);
    acl_t empty=acl_get_file_at(d,"",AT_EMPTY_PATH,ACL_TYPE_DEFAULT);
    assert(empty && acl_entries(empty) == 0); acl_free(empty);
    errno=0; assert(!acl_get_file_at(d,"file",0x40000000,ACL_TYPE_ACCESS) && errno == EINVAL);
    INVALID(acl_set_file_at(d,"file",0x40000000,ACL_TYPE_ACCESS,a));
    INVALID(acl_extended_file_at(d,"file",0x40000000));
    INVALID(acl_delete_def_file_at(d,".",0x40000000));
    equal(a,acl_get_file_at(d,"file",0,ACL_TYPE_ACCESS));
    close(f); close(d); acl_free(a);
    fprintf(stderr,"PASS at: dirfd, empty path, symlinks, invalid flags, default ACLs\n");
}
