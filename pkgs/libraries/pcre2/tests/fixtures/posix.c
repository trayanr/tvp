#define _GNU_SOURCE
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <pcre2posix.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef EXPECTED_LIBRARY
#include <dlfcn.h>
#include <limits.h>
#endif
int main(void)
{
#ifdef EXPECTED_LIBRARY
  Dl_info info;
  char loaded[PATH_MAX], declared[PATH_MAX];
  assert(dladdr((void *)pcre2_regcomp, &info));
  assert(realpath(info.dli_fname, loaded) && realpath(EXPECTED_LIBRARY, declared));
  assert(strcmp(loaded, declared) == 0);
  assert(dladdr((void *)pcre2_config, &info));
  assert(realpath(info.dli_fname, loaded) && realpath(EXPECTED_ENGINE, declared));
  assert(strcmp(loaded, declared) == 0);
#endif
  regex_t re;
  regmatch_t m[2];
  assert(regcomp(&re, "([a-z]+)-[0-9]+", REG_EXTENDED | REG_ICASE) == 0);
  assert(regexec(&re, "!TVP-42!", 2, m, 0) == 0);
  assert(m[0].rm_so == 1 && m[0].rm_eo == 7 && m[1].rm_so == 1 && m[1].rm_eo == 4);
  assert(regexec(&re, "no digits", 2, m, 0) == REG_NOMATCH);
  regfree(&re);
  puts("posix captures/nomatch ok");
}
