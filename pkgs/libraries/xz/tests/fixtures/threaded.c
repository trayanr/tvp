#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <lzma.h>

int main(void)
{
    const char *message = "tvp preserves what other software is built on";
    lzma_stream strm = LZMA_STREAM_INIT;
    lzma_mt mt;
    uint8_t packed[4096];
    uint8_t out[512];
    size_t packed_size;
    size_t in_pos = 0;
    size_t out_pos = 0;
    uint64_t memlimit = UINT64_MAX;

    memset(&mt, 0, sizeof mt);
    mt.threads = 2;
    mt.preset = 6;
    mt.check = LZMA_CHECK_CRC64;

    if (lzma_stream_encoder_mt(&strm, &mt) != LZMA_OK)
        return 1;
    strm.next_in = (const uint8_t *)message;
    strm.avail_in = strlen(message);
    strm.next_out = packed;
    strm.avail_out = sizeof packed;
    if (lzma_code(&strm, LZMA_FINISH) != LZMA_STREAM_END)
        return 1;
    packed_size = sizeof packed - strm.avail_out;
    lzma_end(&strm);

    if (lzma_stream_buffer_decode(&memlimit, 0, NULL, packed, &in_pos, packed_size, out, &out_pos,
                                  sizeof out) != LZMA_OK)
        return 1;

    fwrite(out, 1, out_pos, stdout);
    putchar('\n');
    return 0;
}
