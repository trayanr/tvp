#define _DEFAULT_SOURCE
#include <errno.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <unistd.h>
/* This separate child changes only its own process credentials. */
int main(void) {
    struct passwd *pw = getpwuid(getuid());
    if (!pw) { perror("independent getpwuid"); return 1; }
    if (initgroups(pw->pw_name, getgid())) {
        int error = errno;
        perror("independent initgroups");
        return error == EPERM ? 77 : 1;
    }
    return 0;
}
