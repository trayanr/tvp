#include <nghttp2/nghttp2.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    nghttp2_hd_deflater *deflater; nghttp2_hd_inflater *inflater;
    nghttp2_nv headers[] = {
        {(uint8_t *)":method", (uint8_t *)"GET", 7, 3, NGHTTP2_NV_FLAG_NONE},
        {(uint8_t *)"x-tvp", (uint8_t *)"42", 5, 2, NGHTTP2_NV_FLAG_NONE}
    };
    if (nghttp2_hd_deflate_new(&deflater, 4096) || nghttp2_hd_inflate_new(&inflater)) return 1;
    uint8_t encoded[1024];
    ssize_t size = nghttp2_hd_deflate_hd(deflater, encoded, sizeof encoded, headers, 2);
    if (size <= 0) return 2;
    size_t offset = 0, count = 0;
    for (;;) {
        nghttp2_nv decoded; int flags;
        ssize_t used = nghttp2_hd_inflate_hd2(inflater, &decoded, &flags, encoded + offset, size - offset, 1);
        if (used < 0) return 3;
        offset += used;
        if (flags & NGHTTP2_HD_INFLATE_EMIT) {
            if (count >= 2 || decoded.namelen != headers[count].namelen || decoded.valuelen != headers[count].valuelen ||
                memcmp(decoded.name, headers[count].name, decoded.namelen) || memcmp(decoded.value, headers[count].value, decoded.valuelen)) return 4;
            ++count;
        }
        if (flags & NGHTTP2_HD_INFLATE_FINAL) break;
        if (!used && !(flags & NGHTTP2_HD_INFLATE_EMIT)) return 5;
    }
    if (count != 2 || offset != (size_t)size) return 6;
    nghttp2_hd_inflate_end_headers(inflater);
    nghttp2_hd_inflate_del(inflater); nghttp2_hd_deflate_del(deflater);
    puts(nghttp2_version(0)->version_str); return 0;
}
