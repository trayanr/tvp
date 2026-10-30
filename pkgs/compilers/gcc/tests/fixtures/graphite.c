#include <stdio.h>
static int values[16][16];
int main(int argc, char **argv)
{
    int n = argc + 15;
    int sum = 0;
    if (n > 16) return 1;
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            values[i][j] = i + j;
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            sum += values[i][j];
    printf("%d\n", sum);
    return 0;
}
