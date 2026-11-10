#include <lzma.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    const uint8_t input[] = "bounded raw LZMA2 filter";
    uint8_t packed[1024], restored[128];
    size_t packed_size = 0, in_pos = 0, out_pos = 0;
    lzma_options_lzma options;
    if (lzma_lzma_preset(&options, 1)) return 1;
    lzma_filter filters[] = {{LZMA_FILTER_LZMA2, &options}, {LZMA_VLI_UNKNOWN, NULL}};
    if (lzma_raw_buffer_encode(filters, NULL, input, sizeof input, packed,
                               &packed_size, sizeof packed) != LZMA_OK) return 2;
    if (lzma_raw_buffer_decode(filters, NULL, packed, &in_pos, packed_size,
                               restored, &out_pos, sizeof restored) != LZMA_OK) return 3;
    if (out_pos != sizeof input || memcmp(input, restored, out_pos)) return 4;
    puts("filter");
    return 0;
}
