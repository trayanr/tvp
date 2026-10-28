#include <stdio.h>
int answer(void);
int cppanswer(void);
int main(void) {
    if (answer() != cppanswer()) return 1;
    printf("%d\n", answer());
    return 0;
}
