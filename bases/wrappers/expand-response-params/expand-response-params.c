/* Adapted from Nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b,
 * pkgs/build-support/expand-response-params/expand-response-params.c.
 * Copyright (c) 2003-2024 Eelco Dolstra and the Nixpkgs/NixOS contributors.
 * MIT licence: see COPYING. Preserve GCC's quote/backslash/EOF grammar;
 * bound expansion and report I/O errors before the wrapper invokes GCC.
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>

#define MAX_DEPTH 64
#define MAX_BYTES (16 * 1024 * 1024)
#define MAX_ARGS 100000

typedef struct { char *data; size_t len, cap; } String;
static size_t bytes, args;
static struct { dev_t dev; ino_t ino; } active[MAX_DEPTH];

static void fail(const char *message) {
    fprintf(stderr, "expand-response-params: %s\n", message);
    exit(EXIT_FAILURE);
}
static void append(String *s, char c) {
    if (++bytes > MAX_BYTES) fail("expansion exceeds 16 MiB");
    if (s->len == s->cap) {
        s->cap = s->cap ? s->cap * 2 : 64;
        s->data = realloc(s->data, s->cap);
        if (!s->data) fail("out of memory");
    }
    s->data[s->len++] = c;
}

typedef enum { space, other, backslash, apostrophe, quotation_mark } CharClass;
typedef enum { outside, unq, unq_esc, sq, sq_esc, dq, dq_esc } State;
static const State transitions[][5] = {
    [outside] = {outside, unq, unq_esc, sq,  dq},
    [unq]     = {outside, unq, unq_esc, sq,  dq},
    [unq_esc] = {unq,     unq, unq,     unq, unq},
    [sq]      = {sq,      sq,  sq_esc,  unq, sq},
    [sq_esc]  = {sq,      sq,  sq,      sq,  sq},
    [dq]      = {dq,      dq,  dq_esc,  dq,  unq},
    [dq_esc]  = {dq,      dq,  dq,      dq,  dq},
};
static CharClass charClass(int c) {
    return c == '\\' ? backslash : c == '\'' ? apostrophe : c == '"' ? quotation_mark :
        isspace((unsigned char)c) ? space : other;
}
static void expandArg(const char *arg, unsigned depth) {
    FILE *f;
    struct stat st;
    if (arg[0] != '@' || !arg[1]) goto literal;
    /* Do not read stdin, devices or pipes during classification and then ask
     * GCC to read them a second time. Missing files remain literal, like GCC. */
    if (!strcmp(arg + 1, "/dev/stdin") || !strncmp(arg + 1, "/dev/fd/", 8) ||
        (!strncmp(arg + 1, "/proc/", 6) && strstr(arg + 1, "/fd/")))
        fail("response files must be regular files (no stdin/fd paths)");
    if (stat(arg + 1, &st)) goto literal;
    if (!S_ISREG(st.st_mode)) fail("response files must be regular files (no stdin/devices/pipes)");
    if (depth == MAX_DEPTH) fail("response nesting exceeds 64 files");
    for (unsigned i = 0; i < depth; ++i)
        if (active[i].dev == st.st_dev && active[i].ino == st.st_ino)
            fail("cyclic response file");
    active[depth].dev = st.st_dev;
    active[depth].ino = st.st_ino;
    f = fopen(arg + 1, "r");
    if (!f) fail("cannot open response file");
    String word = {0};
    State cur = outside;
    int c;
    while ((c = fgetc(f)) != EOF) {
        if (c == 0) fail("NUL in response file is unsupported");
        State next = transitions[cur][charClass(c)];
        if (cur == unq && next == outside) {
            append(&word, 0);
            expandArg(word.data, depth + 1);
            word.len = 0;
        } else if (cur == unq_esc || cur == sq_esc || cur == dq_esc ||
                   (cur == outside ? next == unq : cur == next)) {
            append(&word, c);
        }
        /* Bound whitespace too: an all-whitespace file must not evade limits. */
        if (++bytes > MAX_BYTES) fail("expansion exceeds 16 MiB");
        cur = next;
    }
    if (ferror(f)) fail("error reading response file");
    if (fclose(f)) fail("error closing response file");
    /* GCC accepts unmatched quotes and a trailing escape at EOF. */
    if (cur != outside) {
        append(&word, 0);
        expandArg(word.data, depth + 1);
    }
    free(word.data);
    return;
literal:
    if (++args > MAX_ARGS) fail("expansion exceeds 100000 arguments");
    size_t len = strlen(arg) + 1;
    if (len > MAX_BYTES - bytes) fail("expansion exceeds 16 MiB");
    bytes += len;
    if (fwrite(arg, 1, len, stdout) != len) fail("error writing arguments");
}
int main(int argc, char **argv) {
    (void)argc;
    while (*++argv) expandArg(*argv, 0);
    if (fflush(stdout) || ferror(stdout)) fail("error writing arguments");
    return EXIT_SUCCESS;
}
