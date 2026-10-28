#include <linux/version.h>
#include <linux/futex.h>
#include <linux/openat2.h>
#include <asm/unistd.h>
#include <stdio.h>
_Static_assert(LINUX_VERSION_CODE == TVP_EXPECTED_VERSION_CODE, "headers version");
int main(void) {
    struct open_how how = { .flags = 0, .resolve = RESOLVE_BENEATH };
    if (FUTEX_WAIT != 0 || __NR_read != 0 || how.resolve != RESOLVE_BENEATH) return 1;
    puts("ok");
    return 0;
}
