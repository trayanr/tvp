#include <libxslt/xslt.h>
#include <stdio.h>

int main(void)
{
    if (xsltLibxsltVersion <= 0)
        return 1;
    fputs("libxslt", stdout);
    return 0;
}
