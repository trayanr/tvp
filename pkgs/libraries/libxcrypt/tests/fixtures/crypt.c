#include <crypt.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    struct crypt_data first = {0}, second = {0};
    const char *hash = crypt_r("password", "$6$salt$", &first);
    if (!hash || strncmp(hash, "$6$salt$", 8)) return 1;
    const char *match = crypt_r("password", hash, &second);
    if (!match || strcmp(hash, match)) return 2;
    const char *different = crypt_r("different", hash, &second);
    if (!different || !strcmp(hash, different)) return 3;
    puts("ok");
    return 0;
}
