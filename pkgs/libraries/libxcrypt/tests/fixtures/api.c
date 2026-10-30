#define _GNU_SOURCE
#include <crypt.h>
#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s (errno=%d)\n", __LINE__, #c, errno); exit(1); } } while (0)
static int valid(const char *s) { return s && *s && *s != '*'; }
static void equal(const char *s, const char *want) {
  if (!s || strcmp(s, want)) {
    fprintf(stderr, "FAIL equal: got %s, expected %s\n", s ? s : "NULL", want);
    exit(1);
  }
}
static const struct { int sm3; const char *setting, *hash, *phrase; } vectors[] = {
#include "vectors.h"
};
static const char entropy[] = "\x58\x35\xcd\x26\x03\xab\x2c\x14\x92\x13\x1e\x59\xb0\xbc\xfe\xd5";

static void known_answers(int historical) {
  struct crypt_data a = {0}, b = {0};
  void *allocated = NULL;
  int size = 0;
  for (size_t i = 0; i < sizeof(vectors)/sizeof(*vectors); i++) {
    const char *setting = vectors[i].setting, *hash = vectors[i].hash, *phrase = vectors[i].phrase;
    if (historical && vectors[i].sm3) {
      CHECK(crypt_checksalt(setting) == CRYPT_SALT_INVALID);
      CHECK(!valid(crypt_r(phrase, setting, &a)));
      printf("SKIP known-answer %s: absent in 4.4.36; rejection PASS\n", setting);
      continue;
    }
    equal(crypt(phrase, setting), hash);
    equal(crypt_r(phrase, setting, &a), hash);
    equal(crypt_rn(phrase, setting, &b, sizeof b), hash);
    equal(crypt_ra(phrase, setting, &allocated, &size), hash);
    CHECK(size >= (int)sizeof(struct crypt_data));
    /* Separate data objects must not overwrite one another. */
    CHECK(valid(crypt_r("dummy-other", setting, &b)));
    equal(a.output, hash);
    CHECK(strcmp(a.output, b.output));
    equal(crypt_r(phrase, hash, &b), hash);
    CHECK(crypt_checksalt(hash) != CRYPT_SALT_INVALID);
    printf("PASS known-answer four APIs/reentrancy %s\n", setting);
  }
  free(allocated);
}

static void bad_arguments(void) {
  struct crypt_data data = {0};
  const char *invalid[] = {"*0", "*1", "$invalid$", "$2$", "!!"};
  void *allocated = NULL;
  int size = 0;
  for (size_t i = 0; i < sizeof invalid/sizeof *invalid; i++) {
    CHECK(crypt_checksalt(invalid[i]) == CRYPT_SALT_INVALID);
    CHECK(!valid(crypt("dummy", invalid[i])));
    CHECK(!valid(crypt_r("dummy", invalid[i], &data)));
    CHECK(crypt_rn("dummy", invalid[i], &data, sizeof data) == NULL);
    CHECK(crypt_ra("dummy", invalid[i], &allocated, &size) == NULL);
  }
  free(allocated);
  /* Upstream short-outbuf.c expectations, with sentinel bounds. */
  const char *expected[] = {"", "*", "*0"};
  for (int n = 1; n <= 3; n++) {
    unsigned char buf[5]; memset(buf, 0x5a, sizeof buf);
    CHECK(crypt_rn("@@", "@@", buf, n) == NULL);
    CHECK(!memcmp(buf, expected[n-1], n));
    CHECK(buf[n] == 0x5a);
  }
  for (int n = 1; n <= 3; n++) {
    allocated = malloc(n); CHECK(allocated); size = n;
    CHECK(crypt_ra("@@", "@@", &allocated, &size) == NULL);
    CHECK(size >= (int)sizeof(struct crypt_data));
    equal(allocated, "*0"); free(allocated);
  }
  char salt[CRYPT_GENSALT_OUTPUT_SIZE];
  CHECK(crypt_gensalt_rn("$6$", 0, entropy, 16, salt, 1) == NULL);
  CHECK(crypt_gensalt_rn("$invalid$", 0, entropy, 16, salt, sizeof salt) == NULL);
  puts("PASS invalid settings/short buffers");
}

static void salts(int historical) {
  /* Fixed entropy and expected outputs from upstream test/gensalt.c. */
  const char *prefixes[] = {"$5$", "$6$", "$sm3$", "$sm3y$"};
  const char *expected[] = {"$5$MJHnaAkegEVYHsFK", "$6$MJHnaAkegEVYHsFK",
    "$sm3$MJHnaAkegEVYHsFK", "$sm3y$j9T$MJHnaAkegEVYHsFKkmfzJ1"};
  for (int i = 0; i < 4; i++) {
    char output[CRYPT_GENSALT_OUTPUT_SIZE];
    if (historical && i >= 2) {
      CHECK(crypt_gensalt_rn(prefixes[i], 0, entropy, 16, output, sizeof output) == NULL);
      printf("SKIP gensalt %s: absent in 4.4.36; rejection PASS\n", prefixes[i]);
      continue;
    }
    equal(crypt_gensalt(prefixes[i], 0, entropy, 16), expected[i]);
    equal(crypt_gensalt_rn(prefixes[i], 0, entropy, 16, output, sizeof output), expected[i]);
    char *p = crypt_gensalt_ra(prefixes[i], 0, entropy, 16);
    equal(p, expected[i]); free(p);
    CHECK(crypt_checksalt(output) == ((i == 0 || i == 2) ? CRYPT_SALT_METHOD_LEGACY : CRYPT_SALT_OK));
    printf("PASS deterministic gensalt three APIs %s\n", prefixes[i]);
  }
}

/* Upstream #209 / test/{crypt,gensalt}-nested-call.c. Bounded SHA512 case.
 * Compare aliasing with independent non-overlapping controls, including keys.
 * 4.4.36's premature failure-token write is an observed historical outcome. */
static void aliases(int historical) {
  const char *setting = "$6$rounds=1000$saltstring";
  char saved[CRYPT_OUTPUT_SIZE], expected_key[CRYPT_OUTPUT_SIZE], overwritten_key[CRYPT_OUTPUT_SIZE];
  struct crypt_data control = {0}, data = {0};
  strcpy(saved, crypt_r("alexander", setting, &control));
  strcpy(expected_key, crypt_r(saved, setting, &control));
  strcpy(overwritten_key, crypt_r("*0", setting, &control));
  for (int api = 0; api < 4; api++) {
    void *p = NULL; int size = 0; char *value;
    if (api == 0) value = crypt("alexander", setting);
    else if (api == 1) value = crypt_r("alexander", setting, &data);
    else if (api == 2) value = crypt_rn("alexander", setting, &data, sizeof data);
    else value = crypt_ra("alexander", setting, &p, &size);
    equal(value, saved);
    if (api == 0) value = crypt("alexander", value);
    else if (api == 1) value = crypt_r("alexander", value, &data);
    else if (api == 2) value = crypt_rn("alexander", value, &data, sizeof data);
    else value = crypt_ra("alexander", value, &p, &size);
    if (historical) {
      if (api < 2) equal(value, "*1");
      else {
        CHECK(value == NULL);
        equal(api == 2 ? data.output : p, "*1");
      }
    } else equal(value, saved);
    /* Restore a valid result before testing output used as the phrase. */
    if (api == 0) { value = crypt("alexander", setting); value = crypt(value, setting); }
    else if (api == 1) { value = crypt_r("alexander", setting, &data); value = crypt_r(value, setting, &data); }
    else if (api == 2) { value = crypt_rn("alexander", setting, &data, sizeof data); value = crypt_rn(value, setting, &data, sizeof data); }
    else { value = crypt_ra("alexander", setting, &p, &size); value = crypt_ra(value, setting, &p, &size); }
    if (historical) equal(value, overwritten_key); else equal(value, expected_key);
    printf("PASS #209 crypt API %d setting/phrase alias: %s\n", api, historical ? "historical overwrite reproduced" : "corrected");
    free(p);
  }
  char output[CRYPT_GENSALT_OUTPUT_SIZE];
  char *p = crypt_gensalt("$6$", 0, entropy, 16);
  CHECK(p); p = crypt_gensalt(p, 0, entropy, 16);
  if (historical) CHECK(p == NULL); else equal(p, "$6$MJHnaAkegEVYHsFK");
  CHECK(crypt_gensalt_rn("$6$", 0, entropy, 16, output, sizeof output));
  p = crypt_gensalt_rn(output, 0, entropy, 16, output, sizeof output);
  if (historical) CHECK(p == NULL); else equal(p, "$6$MJHnaAkegEVYHsFK");
  puts("PASS #209 gensalt static/caller-buffer alias controls");
}

int main(int argc, char **argv) {
  CHECK(argc == 3);
  Dl_info info;
  char actual[PATH_MAX], expected[PATH_MAX];
  CHECK(dladdr((void *)crypt_r, &info));
  CHECK(realpath(info.dli_fname, actual)); CHECK(realpath(argv[1], expected));
  equal(actual, expected);
  printf("PASS exact loaded library %s\n", actual);
  int historical = !strcmp(argv[2], "4.4.36");
  known_answers(historical); bad_arguments(); salts(historical); aliases(historical);
  puts("PASS bounded API suite");
  return 0;
}
