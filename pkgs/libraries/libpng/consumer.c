#include <stdio.h>
#include <png.h>

int main(void) {
    if (png_access_version_number() != PNG_LIBPNG_VER) {
        return 1;
    }
    printf("%s", png_get_libpng_ver(NULL));
    return 0;
}
