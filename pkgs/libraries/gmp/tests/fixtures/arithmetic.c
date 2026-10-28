#include <gmp.h>
#include <stdio.h>
int main(void) { mpz_t n; mpz_init(n); mpz_ui_pow_ui(n, 2, 128); gmp_printf("%Zd\n", n); mpz_clear(n); return 0; }
