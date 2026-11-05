#define _GNU_SOURCE
#include <locale.h>
#include <stdio.h>
#include <string.h>

extern const char *_g_locale_charset_raw(void);
extern const char *_g_locale_charset_unalias(const char *);
extern FILE *__real_fopen(const char *, const char *);
extern FILE *__real_fopen64(const char *, const char *);

static char opened[4096];

FILE *__wrap_fopen(const char *path, const char *mode) {
  snprintf(opened, sizeof opened, "%s", path);
  return __real_fopen(path, mode);
}

FILE *__wrap_fopen64(const char *path, const char *mode) {
  snprintf(opened, sizeof opened, "%s", path);
  return __real_fopen64(path, mode);
}

int main(int argc, char **argv) {
  if (argc != 5 || !setlocale(LC_ALL, argv[1])) return 2;
  const char *alias = _g_locale_charset_unalias("TVP_ALIAS");
  const char *raw = _g_locale_charset_raw();
  if (strcmp(opened, argv[2]) || strcmp(alias, argv[3]) ||
      strcmp(raw, argv[4])) {
    fprintf(stderr, "path=%s alias=%s charset=%s\n", opened, alias, raw);
    return 3;
  }
  printf("path=%s alias=%s charset=%s\n", opened, alias, raw);
  return 0;
}
