#include <brotli/decode.h>
#include <brotli/encode.h>

#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const uint8_t input[] = "Brotli API round trip";
    uint8_t compressed[256], output[sizeof(input)];
    size_t compressed_size = sizeof(compressed), output_size = sizeof(output);

    if (!BrotliEncoderCompress(BROTLI_DEFAULT_QUALITY, BROTLI_DEFAULT_WINDOW,
                               BROTLI_MODE_GENERIC, sizeof(input), input,
                               &compressed_size, compressed)) {
        return 1;
    }
    if (BrotliDecoderDecompress(compressed_size, compressed, &output_size,
                               output) != BROTLI_DECODER_RESULT_SUCCESS ||
        output_size != sizeof(input) || memcmp(input, output, sizeof(input))) {
        return 1;
    }
    puts("Brotli C API");
    return 0;
}
