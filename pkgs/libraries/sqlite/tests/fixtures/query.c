#include <stdio.h>
#include <sqlite3.h>

static int row(void *unused, int columns, char **values, char **names)
{
    (void)unused;
    (void)names;
    if (columns > 0 && values[0])
        printf("%s\n", values[0]);
    return 0;
}

int main(void)
{
    sqlite3 *db;

    if (sqlite3_open(":memory:", &db) != SQLITE_OK)
        return 1;
    if (sqlite3_exec(db, "create table t(a text); insert into t values('tvp');", NULL, NULL, NULL)
        != SQLITE_OK)
        return 1;
    if (sqlite3_exec(db, "select a from t", row, NULL, NULL) != SQLITE_OK)
        return 1;

    sqlite3_close(db);
    return 0;
}
