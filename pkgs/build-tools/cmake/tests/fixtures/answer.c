#include <iconv.h>
#include <zlib.h>
int answer(void) {
    iconv_t converter = iconv_open("UTF-8", "UTF-8");
    if (converter == (iconv_t)-1 || compressBound(42) <= 42) return 1;
    iconv_close(converter);
    return 42;
}
