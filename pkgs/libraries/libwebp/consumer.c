#include <stdio.h>
#include <webp/decode.h>
#include <webp/encode.h>

int main(void) {
    const int version = WebPGetDecoderVersion();
    if (WebPGetEncoderVersion() != version) {
        return 1;
    }
    printf("%d.%d.%d", version >> 16, (version >> 8) & 0xff, version & 0xff);
    return 0;
}
