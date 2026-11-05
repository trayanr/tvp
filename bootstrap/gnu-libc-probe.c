#define _GNU_SOURCE
#include <assert.h>
#include <ctype.h>
#include <dlfcn.h>
#include <errno.h>
#include <iconv.h>
#include <langinfo.h>
#include <link.h>
#include <locale.h>
#include <paths.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <wchar.h>
#include <wctype.h>
#include <wordexp.h>

#ifndef PROFILE_LIBC
#error explicit profile required
#endif
static int modules;
#ifndef STATIC_PROBE
static int module(struct dl_phdr_info *info, size_t size, void *data) {
    (void)size; (void)data;
    if (strstr(info->dlpi_name, "/gconv/")) {
        assert(!strncmp(info->dlpi_name, PROFILE_LIBC "/lib/gconv/", strlen(PROFILE_LIBC "/lib/gconv/")));
        printf("module=%s\n", info->dlpi_name);
        modules++;
    }
    return 0;
}
#endif
static void conversion(const char *to, const char *from, const char *input,
                       size_t inlen, const char *expected, size_t outlen) {
    iconv_t cd = iconv_open(to, from);
    assert(cd != (iconv_t)-1);
    char result[32] = {0}, *in = (char *)input, *out = result;
    size_t left = inlen, space = sizeof result;
    assert(iconv(cd, &in, &left, &out, &space) == 0);
    assert(left == 0 && (size_t)(out - result) == outlen);
    assert(!memcmp(result, expected, outlen));
#ifndef STATIC_PROBE
    dl_iterate_phdr(module, NULL);
#endif
    assert(iconv_close(cd) == 0);
}
static void rejection(const char *input, size_t length, int error, size_t space) {
    iconv_t cd = iconv_open("UTF-16LE", "UTF-8");
    char result[16], *out = result, *in = (char *)input;
    size_t left = length;
    errno = 0;
    assert(iconv(cd, &in, &left, &out, &space) == (size_t)-1);
    assert(errno == error && left == length);
    assert(iconv_close(cd) == 0);
}
int main(void) {
    assert(getenv("LOCPATH") == NULL && getenv("GCONV_PATH") == NULL);
    assert(setlocale(LC_ALL, "C.UTF-8"));
    assert(!strcmp(nl_langinfo(CODESET), "UTF-8") && MB_CUR_MAX > 1);
    mbstate_t st = {0}; wchar_t wc;
    assert(mbrtowc(&wc, "\xc3\xa9", 2, &st) == 2 && wc == 0xe9);
    assert(iswalpha(wc) && towupper(wc) == 0xc9 && iswspace(0x2003));
    char utf8[8]; memset(&st, 0, sizeof st);
    assert(wcrtomb(utf8, wc, &st) == 2 && !memcmp(utf8, "\xc3\xa9", 2));
    memset(&st, 0, sizeof st); errno = 0;
    assert(mbrtowc(&wc, "\xff", 1, &st) == (size_t)-1 && errno == EILSEQ);
    assert(!setlocale(LC_ALL, "tvp_UNSUPPORTED.UTF-8"));
    conversion("ISO-8859-1", "UTF-8", "A\xc3\xa9", 3, "A\xe9", 2);
    conversion("UTF-8", "ISO-8859-1", "A\xe9", 2, "A\xc3\xa9", 3);
    conversion("UTF-16LE", "UTF-8", "A\xc3\xa9", 3, "A\0\xe9\0", 4);
    conversion("UTF-8", "UTF-16LE", "A\0\xe9\0", 4, "A\xc3\xa9", 3);
    rejection("\xff", 1, EILSEQ, 16);
    rejection("\xc3", 1, EINVAL, 16);
    rejection("A", 1, E2BIG, 0);
    errno = 0;
    assert(iconv_open("TVP-UNSUPPORTED", "UTF-8") == (iconv_t)-1 && errno == EINVAL);
#ifndef STATIC_PROBE
    assert(modules >= 4);
    Dl_info origin;
    assert(dladdr(dlsym(RTLD_DEFAULT, "setlocale"), &origin));
    assert(!strcmp(origin.dli_fname, PROFILE_LIBC "/lib/libc.so.6"));
    printf("libc=%s\n", origin.dli_fname);
#endif
    assert(!strcmp(_PATH_BSHELL, PROFILE_SHELL));
    assert(system(NULL) != 0);
    int status = system("test /proc/$$/exe -ef '" PROFILE_SHELL "' || exit 99; exit 37");
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 37);
    FILE *pipe = popen("test /proc/$$/exe -ef '" PROFILE_SHELL "' || exit 98; printf staged-shell; exit 23", "r");
    assert(pipe); char buf[64] = {0};
    assert(fread(buf, 1, sizeof buf, pipe) == 12 && !strcmp(buf, "staged-shell"));
    status = pclose(pipe);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 23);
    wordexp_t words;
    assert(wordexp("$(test /proc/$$/exe -ef '" PROFILE_SHELL "' && printf staged-wordexp)", &words, 0) == 0);
    assert(words.we_wordc == 1 && !strcmp(words.we_wordv[0], "staged-wordexp")); wordfree(&words);
    assert(wordexp("$(printf forbidden)", &words, WRDE_NOCMD) == WRDE_CMDSUB);
    printf("PASS locale=7 conversions=4 rejection=4 shell=5 staged=%s\n", PROFILE_SHELL);
    return 0;
}
