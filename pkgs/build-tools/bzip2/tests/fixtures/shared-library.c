#include <bzlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    char input[] = "tvp bzip2 shared library roundtrip";
    char compressed[256], restored[sizeof input];
    unsigned int compressed_size = sizeof compressed;
    unsigned int restored_size = sizeof restored;
    const char *version = BZ2_bzlibVersion();

    if (argc != 2 || strncmp(version, argv[1], strlen(argv[1])) != 0 ||
        version[strlen(argv[1])] != ',')
        return 1;
    if (BZ2_bzBuffToBuffCompress(compressed, &compressed_size, input,
                                sizeof input, 9, 0, 30) != BZ_OK)
        return 2;
    if (BZ2_bzBuffToBuffDecompress(restored, &restored_size, compressed,
                                  compressed_size, 0, 0) != BZ_OK)
        return 3;
    if (restored_size != sizeof input || memcmp(input, restored, sizeof input))
        return 4;
    puts(argv[1]);
    return 0;
}
