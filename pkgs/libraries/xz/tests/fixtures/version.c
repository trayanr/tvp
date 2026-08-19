#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <lzma.h>

int main(void)
{
    printf("%s\n", lzma_version_string());
    return 0;
}
