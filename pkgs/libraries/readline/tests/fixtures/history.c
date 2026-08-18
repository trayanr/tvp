#include <stdio.h>
#include <readline/history.h>

/* The history library is a separate archive from readline itself, so this
   fails independently when only one of the two is installed correctly. */
int main(void) {
  using_history();
  add_history("tvp");
  add_history("preserves");
  HIST_ENTRY **all = history_list();
  int n = 0;
  while (all && all[n])
    n++;
  printf("%d %s\n", n, all[0]->line);
  return 0;
}
