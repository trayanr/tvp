#define _GNU_SOURCE
#include <gnu/libc-version.h>
#include <linux/version.h>
#include <asm/unistd.h>
#include <langinfo.h>
#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <wchar.h>
_Static_assert(LINUX_VERSION_CODE >= KERNEL_VERSION(6, 9, 0), "selected UAPI");
_Static_assert(__NR_read >= 0, "native syscall UAPI");
int main(void) {
    if (!setlocale(LC_ALL, "C.UTF-8")) return 1;
    if (strcmp(nl_langinfo(CODESET), "UTF-8")) return 2;
    wchar_t wc;
    if (mbrtowc(&wc, "\342\202\254", 3, NULL) != 3 || wc != 0x20ac) return 3;
    puts("ok");
}
