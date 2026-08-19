#include <stdio.h>
#include <sqlite3.h>

int main(void)
{
    sqlite3 *db;
    sqlite3_stmt *stmt;
    const char *text;

    if (sqlite3_open(":memory:", &db) != SQLITE_OK)
        return 1;
    if (sqlite3_exec(db, "create table t(a text); insert into t values('tvp');", NULL, NULL, NULL)
        != SQLITE_OK)
        return 1;
    if (sqlite3_prepare_v2(db, "select a from t", -1, &stmt, NULL) != SQLITE_OK)
        return 1;
    if (sqlite3_step(stmt) != SQLITE_ROW)
        return 1;

    text = (const char *)sqlite3_column_text(stmt, 0);
    printf("%s\n", text ? text : "(null)");

    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return 0;
}
