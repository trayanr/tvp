#include <gdbm.h>
#include <stdio.h>

int main(void) {
  GDBM_FILE db = gdbm_open("tvp.gdbm", 0, GDBM_NEWDB, 0644, NULL);
  if (!db) return 1;

  datum key = { (char *)"k", 1 };
  datum val = { (char *)"tvp", 3 };
  if (gdbm_store(db, key, val, GDBM_INSERT) != 0) return 2;

  datum got = gdbm_fetch(db, key);
  if (!got.dptr) return 3;
  printf("%.*s\n", got.dsize, got.dptr);

  gdbm_close(db);
  return 0;
}
