#include <magic.h>
#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(int argc, char **argv)
{
    const char sample[] = "#!/bin/sh\necho preserved\n";
    const char *expected = "text/x-shellscript";
    magic_t magic = magic_open(MAGIC_MIME_TYPE | MAGIC_COMPRESS |
        MAGIC_COMPRESS_TRANSP);
    gzFile gzip = gzopen("sample.gz", "wb");
    if (!gzip || gzwrite(gzip, sample, sizeof(sample) - 1) != sizeof(sample) - 1 ||
        gzclose(gzip) != Z_OK || !magic || magic_load(magic, NULL) != 0)
        return 1;
    const char *type = magic_buffer(magic, sample, sizeof(sample) - 1);
    if (!type || strcmp(type, expected) != 0)
        return 2;
    for (int i = 1; i < argc; ++i) {
        type = magic_file(magic, argv[i]);
        if (!type || strcmp(type, expected) != 0) {
            fprintf(stderr, "%s: %s (%s)\n", argv[i], type ? type : "NULL",
                magic_error(magic) ? magic_error(magic) : "no error");
            return 3;
        }
    }
    magic_close(magic);
    return 0;
}
