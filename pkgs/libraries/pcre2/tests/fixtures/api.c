#define _GNU_SOURCE
#include <pcre2.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef EXPECTED_LIBRARY
#include <dlfcn.h>
#include <limits.h>
#endif

/* Convert scalar values to the code units of the independently linked width. */
static size_t encode(const uint32_t *s, PCRE2_UCHAR *out)
{
  size_t n = 0;
  for (; *s; ++s) {
    uint32_t c = *s;
#if PCRE2_CODE_UNIT_WIDTH == 8
    if (c < 0x80) out[n++] = c;
    else if (c < 0x800) {
      out[n++] = 0xc0 | (c >> 6); out[n++] = 0x80 | (c & 63);
    } else if (c < 0x10000) {
      out[n++] = 0xe0 | (c >> 12); out[n++] = 0x80 | ((c >> 6) & 63);
      out[n++] = 0x80 | (c & 63);
    } else {
      out[n++] = 0xf0 | (c >> 18); out[n++] = 0x80 | ((c >> 12) & 63);
      out[n++] = 0x80 | ((c >> 6) & 63); out[n++] = 0x80 | (c & 63);
    }
#elif PCRE2_CODE_UNIT_WIDTH == 16
    if (c < 0x10000) out[n++] = c;
    else { c -= 0x10000; out[n++] = 0xd800 | (c >> 10); out[n++] = 0xdc00 | (c & 1023); }
#else
    out[n++] = c;
#endif
  }
  out[n] = 0;
  return n;
}

static void narrow(const PCRE2_UCHAR *s, char *out)
{
  do { *out++ = (char)*s; } while (*s++);
}

static void fixture(const char *name, const char *pattern, const uint32_t *text,
                    size_t start_offset, int identical, int expected_rc, size_t start, size_t end)
{
  PCRE2_UCHAR pat[512], subject[512];
  size_t i, len = encode(text, subject);
  for (i = 0; pattern[i]; ++i) pat[i] = (unsigned char)pattern[i];
  pat[i] = 0;
  int error;
  PCRE2_SIZE offset;
  pcre2_code *re = pcre2_compile(pat, PCRE2_ZERO_TERMINATED, PCRE2_UTF | PCRE2_UCP,
                               &error, &offset, NULL);
  assert(re);
  pcre2_match_data *a = pcre2_match_data_create_from_pattern(re, NULL);
  pcre2_match_data *b = pcre2_match_data_create_from_pattern(re, NULL);
  assert(a && b);
  int interpreter = pcre2_match(re, subject, len, start_offset, PCRE2_NO_JIT, a, NULL);
  assert(pcre2_jit_compile(re, PCRE2_JIT_COMPLETE) == 0);
  PCRE2_SIZE jit_size = 0;
  assert(pcre2_pattern_info(re, PCRE2_INFO_JITSIZE, &jit_size) == 0 && jit_size > 0);
  int jit = pcre2_jit_match(re, subject, len, start_offset, 0, b, NULL);
  PCRE2_SIZE *av = pcre2_get_ovector_pointer(a), *bv = pcre2_get_ovector_pointer(b);
  if (interpreter < 0) av[0] = av[1] = 0;
  if (jit < 0) bv[0] = bv[1] = 0;
  printf("%s interpreter=%d:%zu-%zu jit=%d:%zu-%zu\n", name,
         interpreter, (size_t)av[0], (size_t)av[1], jit, (size_t)bv[0], (size_t)bv[1]);
  if (identical) {
    assert(interpreter == expected_rc && jit == interpreter);
    assert(av[0] == start && av[1] == end);
    assert(memcmp(av, bv, 2 * interpreter * sizeof(*av)) == 0);
  }
#if PCRE2_MAJOR > 10 || (PCRE2_MAJOR == 10 && PCRE2_MINOR >= 47)
  if (strcmp(name, "utf") == 0) {
    PCRE2_SIZE next = 0;
    uint32_t options = 0;
    assert(pcre2_next_match(a, &next, &options) == 1);
    assert(next == end && options == 0);
    assert(pcre2_match(re, subject, len, next, options, a, NULL) == PCRE2_ERROR_NOMATCH);
  }
#endif
  pcre2_match_data_free(a); pcre2_match_data_free(b); pcre2_code_free(re);
}

int main(void)
{
#ifdef EXPECTED_LIBRARY
  Dl_info info;
  char loaded[PATH_MAX], declared[PATH_MAX];
  assert(dladdr((void *)pcre2_config, &info));
  assert(realpath(info.dli_fname, loaded) && realpath(EXPECTED_LIBRARY, declared));
  assert(strcmp(loaded, declared) == 0);
#endif
  uint32_t value;
  PCRE2_UCHAR buffer[128];
  char version[128], unicode[128];
  assert(pcre2_config(PCRE2_CONFIG_VERSION, buffer) > 0); narrow(buffer, version);
  char header[32]; snprintf(header, sizeof(header), "%d.%d ", PCRE2_MAJOR, PCRE2_MINOR);
  assert(strncmp(version, header, strlen(header)) == 0);
  assert(pcre2_config(PCRE2_CONFIG_UNICODE_VERSION, buffer) > 0); narrow(buffer, unicode);
  assert(pcre2_config(PCRE2_CONFIG_JIT, &value) == 0 && value == 1);
  assert(pcre2_config(PCRE2_CONFIG_UNICODE, &value) == 0 && value == 1);
  printf("width=%d version=%d.%d unicode=%s jit=1\n", PCRE2_CODE_UNIT_WIDTH,
         PCRE2_MAJOR, PCRE2_MINOR, unicode);
#if PCRE2_MAJOR > 10 || (PCRE2_MAJOR == 10 && PCRE2_MINOR >= 47)
  assert(pcre2_config(PCRE2_CONFIG_EFFECTIVE_LINKSIZE, &value) == 0);
  printf("effective-linksize=%u\n", value);
  puts("next-match/effective-linksize=enabled");
#else
  puts("next-match/effective-linksize=pre-10.47");
#endif
  fixture("utf", "(\\p{L}+)", (uint32_t[]){0xe9, 0x10400, '!', 0}, 0, 1, 2, 0,
          PCRE2_CODE_UNIT_WIDTH == 8 ? 6 : PCRE2_CODE_UNIT_WIDTH == 16 ? 3 : 2);
  /* Unmodified patterns/subjects from upstream #912 (pcre2_jit_test.c)
     and #841 (testinput5). Historical results are pinned by the Nix suite. */
  fixture("lookbehind-912", "(?<*(.).{,2})\\1", (uint32_t[]){'B','A','B','A',0},
          3, PCRE2_MINOR >= 48, 2, 3, 4);
  fixture("mixed-class-841", "[\\x{ff}\\x{100}\\x{8000}\\x{8002}\\x{8004}\\x{8006}\\x{8008}\\x{800a}\\x{800c}\\x{800e}]+",
          (uint32_t[]){0xff,0x100,0x8000,0x800a,0x800e,0x101,0}, 0, PCRE2_MINOR >= 48,
          1, 0, PCRE2_CODE_UNIT_WIDTH == 8 ? 13 : 5);
  return 0;
}
