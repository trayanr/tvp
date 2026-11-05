#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <wordexp.h>
static __thread int tls_value = 7;
int main(void) {
    void *p = 0;
    char *end, text[32];
    FILE *pipe;
    int status;
    wordexp_t words;
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
    if (setenv("TVP_WORDEXP_VALUE", "owned value", 1)) return 9;
    if (wordexp("\"$TVP_WORDEXP_VALUE\" $(printf shell) $((6 * 7))", &words, 0)) return 10;
    if (words.we_wordc != 3 || strcmp(words.we_wordv[0], "owned value") ||
        strcmp(words.we_wordv[1], "shell") || strcmp(words.we_wordv[2], "42")) return 11;
    wordfree(&words);
    if (wordexp("$(exit 99)", &words, WRDE_NOCMD) != WRDE_CMDSUB) return 12;
    puts("musl allocation/conversion/math/errno/TLS/popen/system/wordexp: PASS");
    return 0;
}
