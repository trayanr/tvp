#include <gdbm/gdbm.h>
#include <stdio.h>

int main(void) {
  GDBM_FILE db = gdbm_open("layout.gdbm", 0, GDBM_NEWDB, 0644, NULL);
  if (!db) return 1;
  printf("tvp\n");
  gdbm_close(db);
  return 0;
}
