#include <stdio.h>
#include <curses.h>
#include <term.h>

/* setupterm reads the compiled terminfo database without needing a tty. */
int main(void) {
  int err = 0;
  if (setupterm("xterm", 1, &err) != OK)
    return 1;
  printf("%d\n", tigetnum("cols"));
  return 0;
}
