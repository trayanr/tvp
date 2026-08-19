#include <stdio.h>
#include <yaml.h>

int main(void)
{
    printf("%s\n", yaml_get_version_string());
    return 0;
}
