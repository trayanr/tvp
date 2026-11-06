#include <gmpxx.h>
#include <mpc.h>
#include <cassert>
int main() {
  mpz_class z = 123456789; z *= z;
  assert(z == mpz_class("15241578750190521"));
  mpc_t c; mpc_init2(c, 128);
  mpc_set_ui_ui(c, 3, 4, MPC_RNDNN);
  mpfr_t a; mpfr_init2(a, 128);
  mpc_abs(a, c, MPFR_RNDN);
  assert(mpfr_cmp_ui(a, 5) == 0);
  mpfr_clear(a); mpc_clear(c);
}
