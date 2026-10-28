#define MPFR_WANT_FLOAT128
#include <mpfr.h>
#include <quadmath.h>
#include <stdio.h>
int main(void) {
    mpfr_t value;
    mpfr_init2(value, 256);
    if (mpfr_set_float128(value, strtoflt128("42", NULL), MPFR_RNDN)) return 1;
    if (mpfr_cmp_ui(value, 42)) return 2;
    mpfr_clear(value);
    puts("42");
    return 0;
}
