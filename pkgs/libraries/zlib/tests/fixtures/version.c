#include <stdio.h>
#include <zlib.h>

/* The runtime version, from the shared library. */
int main(void) {
  printf("%s\n", zlibVersion());
  return 0;
}
