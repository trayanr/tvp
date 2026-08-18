#include <ndbm.h>
#include <fcntl.h>
#include <stdio.h>

int main(void) {
  DBM *db = dbm_open("tvp", O_RDWR | O_CREAT, 0644);
  if (!db) return 1;

  datum key = { (char *)"k", 1 };
  datum val = { (char *)"tvp", 3 };
  if (dbm_store(db, key, val, DBM_INSERT) != 0) return 2;

  datum got = dbm_fetch(db, key);
  if (!got.dptr) return 3;
  printf("%.*s\n", got.dsize, (char *)got.dptr);

  dbm_close(db);
  return 0;
}
