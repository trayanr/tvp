#include <mpc.h>
int main(void) {
  mpc_t z; mpc_init2(z, 100); mpc_set_ui(z, 7, MPC_RNDNN);
  int ok = mpfr_cmp_ui(mpc_realref(z), 7) == 0;
  mpc_clear(z); return !ok;
}
