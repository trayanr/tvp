#include <stdio.h>
#include <zlib.h>

/* The compile-time version, from the header. Paired with version.c this proves
   the header and the library came from the same build. */
int main(void) {
  printf("%s\n", ZLIB_VERSION);
  return 0;
}
