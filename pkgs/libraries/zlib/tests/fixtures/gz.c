#include <zlib.h>

/* Writes a real gzip member, so an external gzip can be asked to read it. */
int main(void) {
  gzFile f = gzopen("out.gz", "wb9");
  if (!f)
    return 1;
  if (gzputs(f, "tvp") < 0)
    return 1;
  return gzclose(f) != Z_OK;
}
