#include <mpfr.h>
#include <stdio.h>
int main(void) { mpfr_t n; mpfr_init2(n, 256); mpfr_set_ui(n, 144, GMP_RNDN); mpfr_sqrt(n, n, GMP_RNDN); if(mpfr_cmp_ui(n, 12)) return 1; mpfr_printf("%.0Rf\n", n); mpfr_clear(n); return 0; }
