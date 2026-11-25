#include <libraw/libraw.h>
#include <stdio.h>

int main(void)
{
    enum { side = 24 };
    unsigned char pixels[side * side];
    for (unsigned int i = 0; i < sizeof(pixels); ++i)
        pixels[i] = 32 + i % 128;

    const unsigned int capabilities = LIBRAW_CAPS_JPEG | LIBRAW_CAPS_ZLIB
                                    | LIBRAW_CAPS_X3FTOOLS | LIBRAW_CAPS_RPI6BY9;
    if (libraw_versionNumber() != LIBRAW_VERSION
        || (libraw_capabilities() & capabilities) != capabilities)
        return 1;

    libraw_data_t *raw = libraw_init(0);
    if (!raw)
        return 1;
    int success = libraw_open_bayer(raw, pixels, sizeof(pixels), side, side,
                                   0, 0, 0, 0, 0, LIBRAW_OPENBAYER_RGGB,
                                   0, 0, 0) == LIBRAW_SUCCESS
               && libraw_unpack(raw) == LIBRAW_SUCCESS
               && raw->sizes.raw_width == side
               && raw->sizes.raw_height == side
               && raw->rawdata.raw_image;
    libraw_close(raw);
    if (!success)
        return 1;
    puts("Bayer unpack");
    return 0;
}
