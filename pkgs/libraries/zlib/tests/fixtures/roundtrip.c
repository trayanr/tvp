#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(void) {
  const char *msg = "tvp preserves what other software is built on";
  Bytef packed[256];
  Bytef out[256];
  uLongf packedLen = sizeof packed;
  uLongf outLen = sizeof out;

  if (compress2(packed, &packedLen, (const Bytef *)msg, strlen(msg) + 1, 9) != Z_OK)
    return 1;
  if (uncompress(out, &outLen, packed, packedLen) != Z_OK)
    return 1;

  printf("%s\n", (char *)out);
  return 0;
}
