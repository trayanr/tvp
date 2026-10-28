#include <stdio.h>
#include <zstd.h>
int main(void) {
    if (ZSTD_VERSION_NUMBER != ZSTD_versionNumber()) return 1;
    puts(ZSTD_versionString());
    return 0;
}
