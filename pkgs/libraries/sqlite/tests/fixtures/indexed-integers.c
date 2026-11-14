#include <sqlite3.h>
#include <stdio.h>

int main(void) {
  static const long long values[] = {
    -9223372036854775807LL - 1, 9223372036854775807LL,
    -140737488355329LL, -1, 0
  };
  static const char *labels[] = {"min", "max", "six-byte-edge", "negative", "zero"};
  sqlite3 *db = 0;
  sqlite3_stmt *insert = 0, *select = 0;
  unsigned i;
  int result = 1;
  if (sqlite3_open(":memory:", &db) != SQLITE_OK) goto done;
  if (sqlite3_exec(db, "CREATE TABLE t(id INTEGER PRIMARY KEY, label TEXT UNIQUE)",
                   0, 0, 0) != SQLITE_OK) goto done;
  if (sqlite3_prepare(db, "INSERT INTO t VALUES(?, ?)", -1, &insert, 0) != SQLITE_OK) goto done;
  for (i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
    if (sqlite3_bind_int64(insert, 1, values[i]) != SQLITE_OK ||
        sqlite3_bind_text(insert, 2, labels[i], -1, SQLITE_STATIC) != SQLITE_OK ||
        sqlite3_step(insert) != SQLITE_DONE || sqlite3_reset(insert) != SQLITE_OK) goto done;
  }
  /* The unique label lookup reads the rowid from the secondary index. */
  if (sqlite3_prepare(db, "SELECT id FROM t WHERE label=?", -1, &select, 0) != SQLITE_OK) goto done;
  for (i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
    if (sqlite3_bind_text(select, 1, labels[i], -1, SQLITE_STATIC) != SQLITE_OK ||
        sqlite3_step(select) != SQLITE_ROW) goto done;
    if (sqlite3_column_int64(select, 0) != values[i]) {
      fprintf(stderr, "indexed integer mismatch: %s\n", labels[i]);
      goto done;
    }
    if (sqlite3_step(select) != SQLITE_DONE || sqlite3_reset(select) != SQLITE_OK) goto done;
  }
  puts("indexed-integers");
  result = 0;
done:
  if (result && db) fprintf(stderr, "SQLite error: %s\n", sqlite3_errmsg(db));
  if (insert) sqlite3_finalize(insert);
  if (select) sqlite3_finalize(select);
  if (db) sqlite3_close(db);
  return result;
}
