#include <gnu/libc-version.h>
#include <linux/version.h>
#include <asm/unistd.h>
#include <errno.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
_Static_assert(__GLIBC__ == 2 && __GLIBC_MINOR__ == 39, "GNU libc 2.39 headers");
_Static_assert(LINUX_VERSION_CODE == KERNEL_VERSION(6,9,0), "Linux 6.9 UAPI");
static _Thread_local int tls = 7;
static void *thread(void *unused) {
    (void)unused;
    if (tls++ != 7) return (void *)1;
    return NULL;
}
int main(void) {
    char cwd[4096];
    if (!getcwd(cwd, sizeof cwd)) { perror("GNU getcwd"); return 20; }
    pthread_t t;
    void *result, *memory;
    if (strcmp(gnu_get_libc_version(), "2.39")) return 1;
    if (posix_memalign(&memory, 64, 128) || (unsigned long)memory % 64) return 2;
    memset(memory, 0x5a, 128);
    if (((unsigned char *)memory)[127] != 0x5a) return 3;
    free(memory);
    errno = 0;
    if (fopen("/tvp-intentionally-absent", "r") || errno != ENOENT) return 4;
    if (pthread_create(&t, NULL, thread, NULL) || pthread_join(t, &result) || result || tls != 7) return 5;
    if (sqrt(144.0) != 12.0 || __NR_getpid <= 0) return 6;
    puts("GNU libc 2.39/Linux 6.9 ABI/headers/allocation/errno/pthread/TLS: PASS");
    return 0;
}
