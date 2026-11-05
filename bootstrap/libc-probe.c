#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
static __thread int tls_value = 7;
int main(void) {
    void *p = 0;
    char *end, text[32];
    FILE *pipe;
    int status;
    if (tls_value++ != 7 || tls_value != 8) return 1;
    if (posix_memalign(&p, 64, 128) || ((unsigned long)p % 64)) return 2;
    memset(p, 0x5a, 128);
    free(p);
    if (strtod("12.5tail", &end) != 12.5 || strcmp(end, "tail")) return 3;
    if (floorl(12.75L) != 12.0L) return 4;
    errno = 0;
    if (fopen("/tvp-intentionally-absent", "r") || errno != ENOENT) return 5;
    pipe = popen("printf owned-shell", "r");
    if (!pipe || !fgets(text, sizeof text, pipe) || strcmp(text, "owned-shell")) return 6;
    if (pclose(pipe)) return 7;
    status = system("exit 7");
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 7) return 8;
    puts("musl allocation/conversion/math/errno/TLS/popen/system: PASS");
    return 0;
}
