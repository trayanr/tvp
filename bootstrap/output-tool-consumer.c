#include <gmp.h>
#include <mpfr.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    mpfr_t x; mpz_t z;
    mpfr_init2(x, 256); mpz_init_set_ui(z, 144);
    mpfr_set_z(x, z, MPFR_RNDN); mpfr_sqrt(x, x, MPFR_RNDN);
    int bad = mpfr_cmp_ui(x, 12) || strcmp(mpfr_get_version(), "4.2.2");
    mpfr_printf("MPFR %s / GMP %s: %.0Rf\n", mpfr_get_version(), gmp_version, x);
    mpz_clear(z); mpfr_clear(x); return bad;
}
