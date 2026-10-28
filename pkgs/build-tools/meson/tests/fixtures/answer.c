#include <zlib.h>
int answer(void) { return compressBound(42) > 42 ? 42 : 1; }
