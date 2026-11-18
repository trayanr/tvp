#include <stdio.h>
#include <sybfront.h>
#include <sybdb.h>

int main(void)
{
    if (dbinit() == FAIL)
        return 1;

    LOGINREC *login = dblogin();
    if (!login) {
        dbexit();
        return 2;
    }

    RETCODE result = DBSETLUSER(login, "tvp");
    dbloginfree(login);
    dbexit();
    if (result == FAIL)
        return 3;

    puts("dblib-ready");
    return 0;
}
