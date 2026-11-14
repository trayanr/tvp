#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <lzma.h>

int main(void)
{
    const char *message = "tvp";
    uint8_t packed[512];
    size_t packed_pos = 0;
    FILE *f;

    if (lzma_easy_buffer_encode(6, LZMA_CHECK_CRC64, NULL, (const uint8_t *)message,
                                strlen(message), packed, &packed_pos, sizeof packed) != LZMA_OK)
        return 1;

    f = fopen("out.xz", "wb");
    if (!f)
        return 1;
    fwrite(packed, 1, packed_pos, f);
    fclose(f);
    return 0;
}
