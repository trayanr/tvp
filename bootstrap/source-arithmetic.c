#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <gmp.h>
#include <mpfr.h>
#include <mpc.h>

/* Check actual mappings as well as the offline ELF and loader observations. */
static void mappings(void) {
    const char *roots[] = { LIBC, LIBGCC, LIBCXX, GMP, MPFR, MPC };
    int seen[6] = {0};
    FILE *f = fopen("/proc/self/maps", "r");
    assert(f);
    char line[8192], self[8192];
    ssize_t nself = readlink("/proc/self/exe", self, sizeof self - 1);
    assert(nself > 0);
    self[nself] = 0;
    while (fgets(line, sizeof line, f)) {
        char *p = strstr(line, "/nix/store/");
        if (!p) continue;
        if (!strncmp(p, self, nself) && p[nself] == '\n') continue;
        int owned = 0;
        for (int i = 0; i < 6; ++i) {
            size_t n = strlen(roots[i]);
            if (!strncmp(p, roots[i], n) && p[n] == '/') { owned = 1; seen[i] = 1; }
        }
        if (!owned) { fputs(line, stderr); abort(); }
        fputs(line, stdout);
    }
    fclose(f);
    assert(seen[0] && seen[3] && seen[4] && seen[5]);
#ifdef __cplusplus
    assert(seen[1] && seen[2]);
#endif
}

static void arithmetic(void) {
    mpz_t a, b, c;
    mpz_inits(a, b, c, NULL);
    mpz_ui_pow_ui(a, 2, 1024);
    mpz_sub_ui(a, a, 1);
    mpz_mul(b, a, a);
    mpz_sqrt(c, b);
    assert(mpz_cmp(a, c) == 0);
    mpz_clears(a, b, c, NULL);
    mpfr_t low, high, pi;
    mpfr_inits2(512, low, high, pi, (mpfr_ptr) 0);
    mpfr_set_ui(low, 2, MPFR_RNDN);
    mpfr_sqrt(high, low, MPFR_RNDU);
    mpfr_sqrt(low, low, MPFR_RNDD);
    assert(mpfr_cmp(low, high) < 0);
    mpfr_nextabove(low);
    assert(mpfr_equal_p(low, high));
    mpfr_const_pi(pi, MPFR_RNDN);
    assert(mpfr_cmp_d(pi, 3.14159) > 0 && mpfr_cmp_d(pi, 3.14160) < 0);
    mpfr_clears(low, high, pi, (mpfr_ptr) 0);
    mpc_t z, square, expected;
    mpc_init2(z, 512); mpc_init2(square, 512); mpc_init2(expected, 512);
    mpc_set_ui_ui(z, 3, 4, MPC_RNDNN);
    mpc_mul(square, z, z, MPC_RNDNN);
    mpc_set_si_si(expected, -7, 24, MPC_RNDNN);
    assert(mpc_cmp(square, expected) == 0);
    mpc_sqrt(square, square, MPC_RNDNN);
    assert(mpc_cmp(square, z) == 0);
    mpc_clear(z); mpc_clear(square); mpc_clear(expected);
    mpfr_free_cache();
}
#ifndef __cplusplus
int main(void) { arithmetic(); mappings(); puts("C arithmetic OK"); return 0; }
#endif
