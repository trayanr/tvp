#include <stdio.h>
#include <string.h>
#include <zstd.h>
int main(void) {
    const char message[] = "tvp preserved";
    char compressed[128], restored[128];
    size_t size = ZSTD_compress(compressed, sizeof(compressed), message, sizeof(message), 3);
    if (ZSTD_isError(size)) return 1;
    size_t decoded = ZSTD_decompress(restored, sizeof(restored), compressed, size);
    if (ZSTD_isError(decoded) || decoded != sizeof(message) || memcmp(message, restored, decoded)) return 1;
    puts(restored);
    return 0;
}
