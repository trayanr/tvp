#include <stdio.h>
int answer(void);
int main(void) { printf("%d", answer()); return answer() != 42; }
