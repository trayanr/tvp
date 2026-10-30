#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/xattr.h>
#include <unistd.h>

int main(void) {
    int fd = open("xattr-probe", O_CREAT | O_EXCL | O_RDWR, 0600);
    if (fd < 0) return 1;
    int ret = fsetxattr(fd, "user.tvp_probe", "1", 1, 0);
    int error = errno;
    close(fd);
    unlink("xattr-probe");
    if (ret == 0) return 0;
    if (error == EOPNOTSUPP) {
        fputs("SKIP: user xattrs unavailable (EOPNOTSUPP); filesystem API and restore tests not run\n", stderr);
        return 77;
    }
    errno = error;
    perror("fsetxattr preflight");
    return 1;
}
