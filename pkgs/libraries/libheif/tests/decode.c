#include <libheif/heif.h>
#include <stdio.h>
#include <stdlib.h>

static void check(heif_error error)
{
    if (error.code != heif_error_Ok) {
        fprintf(stderr, "%s\n", error.message);
        exit(1);
    }
}

int main(int argc, char **argv)
{
    if (argc != 2 || !heif_have_encoder_for_format(heif_compression_HEVC) ||
        !heif_have_decoder_for_format(heif_compression_HEVC))
        return 1;

    heif_context *context = heif_context_alloc();
    if (!context)
        return 1;

    heif_image_handle *handle;
    heif_image *image;
    check(heif_context_read_from_file(context, argv[1], NULL));
    check(heif_context_get_primary_image_handle(context, &handle));
    if (heif_image_handle_get_width(handle) != 64 ||
        heif_image_handle_get_height(handle) != 64)
        return 1;

    check(heif_decode_image(handle, &image, heif_colorspace_YCbCr, heif_chroma_420, NULL));

    if (heif_image_get_width(image, heif_channel_Y) != 64 ||
        heif_image_get_height(image, heif_channel_Y) != 64)
        return 1;

    size_t stride = 0;
    const uint8_t *luma = heif_image_get_plane_readonly2(image, heif_channel_Y, &stride);
    if (!luma || stride < 64 || luma[48 * stride + 32] <= luma[16 * stride + 32] + 64)
        return 1;

    heif_image_release(image);
    heif_image_handle_release(handle);
    heif_context_free(context);
    puts("hevc-roundtrip-ok");
    return 0;
}
