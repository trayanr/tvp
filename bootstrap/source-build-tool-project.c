#include <gmp.h>
#include <mpfr.h>
#include <mpc.h>
#include <stdio.h>
#include "value.h"
int main(void) {
    mpz_t x; mpz_init(x); mpz_ui_pow_ui(x, 2, 256);
    if (mpz_sizeinbase(x, 2) != 257) return 1;
    mpz_clear(x);
    mpfr_t r; mpfr_init2(r, 256); mpfr_set_ui(r, 2, MPFR_RNDN);
    mpfr_sqrt(r, r, MPFR_RNDN);
    if (mpfr_cmp_d(r, 1.4142) <= 0) return 2;
    mpfr_clear(r);
    mpc_t z; mpc_init2(z, 256); mpc_set_ui_ui(z, 3, 4, MPC_RNDNN);
    mpc_mul(z, z, z, MPC_RNDNN);
    int ok = mpfr_cmp_si(mpc_realref(z), -7) == 0 && mpfr_cmp_ui(mpc_imagref(z), 24) == 0;
    mpc_clear(z); mpfr_free_cache();
    if (!ok) return 3;
    printf("C arithmetic %d\n", VALUE);
    return 0;
}
