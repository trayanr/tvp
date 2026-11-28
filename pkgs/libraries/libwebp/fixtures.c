#include <stdio.h>
#include <string.h>

#include <jpeglib.h>
#include <png.h>

enum { WIDTH = 8, HEIGHT = 8, CHANNELS = 3 };

static void png_pixels(unsigned char *pixels)
{
    for (size_t i = 0; i < WIDTH * HEIGHT * CHANNELS; i += CHANNELS) {
        pixels[i] = 12;
        pixels[i + 1] = 34;
        pixels[i + 2] = 56;
    }
}

static int write_jpeg(void)
{
    FILE *file = fopen("input.jpg", "wb");
    if (file == NULL) {
        return 1;
    }

    struct jpeg_compress_struct encoder;
    struct jpeg_error_mgr errors;
    JSAMPLE pixels[WIDTH];
    JSAMPROW row = pixels;

    memset(pixels, 128, sizeof(pixels));
    encoder.err = jpeg_std_error(&errors);
    jpeg_create_compress(&encoder);
    jpeg_stdio_dest(&encoder, file);
    encoder.image_width = WIDTH;
    encoder.image_height = HEIGHT;
    encoder.input_components = 1;
    encoder.in_color_space = JCS_GRAYSCALE;
    jpeg_set_defaults(&encoder);
    jpeg_start_compress(&encoder, TRUE);
    while (encoder.next_scanline < encoder.image_height) {
        jpeg_write_scanlines(&encoder, &row, 1);
    }
    jpeg_finish_compress(&encoder);
    jpeg_destroy_compress(&encoder);
    return fclose(file) != 0;
}

int main(int argc, char **argv)
{
    png_image image = {0};
    unsigned char expected[WIDTH * HEIGHT * CHANNELS];
    unsigned char actual[sizeof(expected)];

    image.version = PNG_IMAGE_VERSION;
    png_pixels(expected);
    if (argc == 2 && strcmp(argv[1], "write") == 0) {
        image.width = WIDTH;
        image.height = HEIGHT;
        image.format = PNG_FORMAT_RGB;
        return !(png_image_write_to_file(&image, "input.png", 0, expected,
                                         0, NULL) && write_jpeg() == 0);
    }
    if (argc != 2 || strcmp(argv[1], "check") != 0) {
        return 1;
    }
    if (!png_image_begin_read_from_file(&image, "decoded.png")) {
        fprintf(stderr, "%s\n", image.message);
        return 1;
    }
    image.format = PNG_FORMAT_RGB;
    const int matches = image.width == WIDTH && image.height == HEIGHT
        && png_image_finish_read(&image, NULL, actual, 0, NULL)
        && memcmp(expected, actual, sizeof(expected)) == 0;
    png_image_free(&image);
    if (!matches) {
        fputs("WebP round trip changed the PNG dimensions or pixels\n", stderr);
    }
    return !matches;
}
