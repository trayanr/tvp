#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <readline/readline.h>
#include <readline/history.h>
static char *generate(const char *text, int state) {
  const char *word = state == 0 ? "terminal" : state == 1 ? "terminfo" : NULL;
  return word && strncmp(text, word, strlen(text)) == 0 ? strdup(word) : NULL;
}
int main(void) {
  char **matches = rl_completion_matches("term", generate);
  int i;
  if (!matches || !matches[1] || !matches[2] || strcmp(matches[0], "termin") != 0) return 1;
  using_history(); add_history(matches[1]); add_history(matches[2]);
  if (history_length != 2 || strcmp(history_get(2)->line, "terminfo") != 0) return 2;
  for (i = 0; matches[i]; i++) free(matches[i]); free(matches);
  clear_history(); puts("completion-history"); return 0;
}
