#include <stdio.h>
#include <sodium.h>

int main(void) {
    if (sodium_init() < 0) {
        return 1;
    }
    printf("%s", sodium_version_string());
    return 0;
}
