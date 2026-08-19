#include <string.h>
#include <zlib.h>

/* Writes a real gzip member, so an external gzip can be asked to read it.
   gzwrite, not gzputs: the string form arrives at 1.0.9. */
int main(void) {
  const char *msg = "tvp";
  gzFile f = gzopen("out.gz", "wb9");
  if (!f)
    return 1;
  if (gzwrite(f, (voidp)msg, (unsigned)strlen(msg)) <= 0)
    return 1;
  return gzclose(f) != Z_OK;
}
