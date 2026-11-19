#include <keyutils.h>
#include <stdio.h>

int main(void)
{
    puts(keyutils_version_string);
    return 0;
}
