#include <libintl.h>
#include <locale.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
  if (argc != 2 || !setlocale(LC_ALL, "fr_FR.UTF-8")) return 1;
  bindtextdomain("fixture", argv[1]); textdomain("fixture");
  if (strcmp(gettext("Hello"), "Bonjour")) return 2;
  if (strcmp(ngettext("apple", "apples", 2), "pommes")) return 3;
  puts("ok"); return 0;
}
