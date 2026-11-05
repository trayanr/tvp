#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int sum(int n) {
  return n ? n + sum(n - 1) : 0;
}

int main(void) {
  char *message = malloc(64);
  if (!message) return 1;
  strcpy(message, "source-built C and libc");
  if (strcmp(message, "source-built C and libc") || sum(9) != 45) return 2;
  printf("%s: %d\n", message, sum(9));
  free(message);
  return 0;
}
