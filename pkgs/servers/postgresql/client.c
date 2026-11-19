#include <libpq-fe.h>
#include <pg_config.h>
#include <stdio.h>

int main(void)
{
    if (PQlibVersion() != PG_VERSION_NUM) {
        fputs("libpq does not match its installed headers\n", stderr);
        return 1;
    }
    puts(PG_VERSION);
    return 0;
}
