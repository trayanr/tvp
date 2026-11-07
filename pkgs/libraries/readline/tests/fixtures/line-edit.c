#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <readline/readline.h>
#include <readline/history.h>
int main(void) {
    rl_readline_name = "tvp-test";
    rl_variable_bind("editing-mode", "emacs");
    char *a = readline("first> ");
    if (!a || strcmp(a, "Xabc")) return 1;
    add_history(a);
    char *b = readline("second> ");
    if (!b || strcmp(b, "XabcY")) return 1;
    if (history_length != 1 || strcmp(history_get(1)->line, a)) return 1;
    puts("readline-edit-history-ok");
    free(a); free(b);
    return 0;
}
