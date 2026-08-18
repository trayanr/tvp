#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(void) {
  const char *msg = "tvp";
  printf("%08lx\n", (unsigned long)crc32(crc32(0L, Z_NULL, 0), (const Bytef *)msg, strlen(msg)));
  return 0;
}
