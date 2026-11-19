#include <stddef.h>
#include <stdio.h>
#include <jpeglib.h>

int main(void) {
    struct jpeg_error_mgr error;
    struct jpeg_compress_struct compressor;
    compressor.err = jpeg_std_error(&error);
    jpeg_create_compress(&compressor);
    jpeg_destroy_compress(&compressor);
    fputs("jpeg", stdout);
    return 0;
}
