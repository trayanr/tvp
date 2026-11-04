#define _DEFAULT_SOURCE
#include <endian.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/xattr.h>
#include <unistd.h>

/* Probe libc/kernel operations independently of the library under test. */
int main(int argc, char **argv) {
    if (argc != 2 || (strcmp(argv[1], "xattrs") && strcmp(argv[1], "acls") &&
                      strcmp(argv[1], "set-id"))) return 2;
    char path[] = ".tvp-filesystem-XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0) { perror("filesystem preflight: mkstemp"); return 1; }
    int rc, unsupported;
    if (!strcmp(argv[1], "set-id")) {
        rc = fchmod(fd, 0600 | S_ISUID | S_ISGID);
        unsupported = EPERM;
    } else if (!strcmp(argv[1], "xattrs")) {
        rc = fsetxattr(fd, "user.tvp_probe", "1", 1, 0);
        unsupported = EOPNOTSUPP;
    } else {
        struct entry { uint16_t tag, permissions; uint32_t id; };
        struct { uint32_t version; struct entry entries[5]; } acl = {
            htole32(2), {
                {htole16(1), htole16(6), htole32(UINT32_MAX)},
                {htole16(2), htole16(4), htole32((uint32_t)geteuid())},
                {htole16(4), htole16(4), htole32(UINT32_MAX)},
                {htole16(16), htole16(4), htole32(UINT32_MAX)},
                {htole16(32), htole16(0), htole32(UINT32_MAX)}
            }
        };
        rc = fsetxattr(fd, "system.posix_acl_access", &acl, sizeof(acl), 0);
        unsupported = EOPNOTSUPP;
    }
    int error = errno, status = 0;
    if (rc < 0) {
        if (error == unsupported) {
            fprintf(stderr, "SKIP: independent %s preflight: %s\n", argv[1], strerror(error));
            status = 77;
        } else {
            fprintf(stderr, "filesystem preflight (%s): %s\n", argv[1], strerror(error));
            status = 1;
        }
    } else if (!strcmp(argv[1], "set-id")) {
        struct stat st;
        if (fstat(fd, &st) || (st.st_mode & (S_ISUID | S_ISGID)) != (S_ISUID | S_ISGID)) {
            fputs("filesystem preflight: set-ID modes were not retained\n", stderr);
            status = 1;
        }
    }
    if (close(fd) || unlink(path)) { perror("filesystem preflight: cleanup"); status = 1; }
    return status;
}
