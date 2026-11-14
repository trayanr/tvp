#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <lzma.h>

int main(void)
{
    const char *message = "tvp preserves what other software is built on";
    uint8_t packed[512];
    uint8_t out[512];
    size_t packed_pos = 0;
    size_t in_pos = 0;
    size_t out_pos = 0;
    uint64_t memlimit = UINT64_MAX;

    if (lzma_easy_buffer_encode(6, LZMA_CHECK_CRC64, NULL, (const uint8_t *)message,
                                strlen(message), packed, &packed_pos, sizeof packed) != LZMA_OK)
        return 1;

    if (lzma_stream_buffer_decode(&memlimit, 0, NULL, packed, &in_pos, packed_pos, out, &out_pos,
                                  sizeof out) != LZMA_OK)
        return 1;

    fwrite(out, 1, out_pos, stdout);
    putchar('\n');
    return 0;
}
