#include <gdbm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
  datum key = {(char *)"key",3}, value = {(char *)"tvp",3}, got;
  GDBM_FILE db = gdbm_open("roundtrip.db",0,GDBM_NEWDB,0600,NULL);
  if (!db || gdbm_store(db,key,value,GDBM_INSERT)) return 1;
  gdbm_close(db);
  db = gdbm_open("roundtrip.db",0,GDBM_WRITER,0600,NULL);
  if (!db) return 2;
  got = gdbm_fetch(db,key);
  if (!got.dptr || got.dsize != 3 || memcmp(got.dptr,"tvp",3)) return 3;
  free(got.dptr);
  if (gdbm_delete(db,key) || gdbm_exists(db,key)) return 4;
  gdbm_close(db);
  puts("write-reopen-fetch-delete");
  return 0;
}
