#include <stdio.h>
#include "scanner.h"
int main(void) {
    yyscan_t scanner;
    if (tvplex_init(&scanner)) return 1;
    YY_BUFFER_STATE buffer = tvp_scan_string("42", scanner);
    int value = tvplex(scanner);
    tvp_delete_buffer(buffer, scanner);
    tvplex_destroy(scanner);
    printf("%d\n", value);
    return value != 42;
}
