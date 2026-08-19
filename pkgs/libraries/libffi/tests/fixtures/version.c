#include <stdio.h>
#include <ffi.h>

int main(void)
{
    printf("%s\n", ffi_get_version());
    return 0;
}
