#include <stdio.h>
#include <mpc.h>
int main(void) { mpc_t a, b; mpc_init2(a, 256); mpc_init2(b, 256); mpc_set_ui_ui(a, 3, 4, MPC_RNDNN); mpc_conj(b, a, MPC_RNDNN); mpc_mul(a, a, b, MPC_RNDNN); if(mpfr_cmp_ui(mpc_realref(a), 25) || mpfr_cmp_ui(mpc_imagref(a), 0)) return 1; puts("25"); mpc_clear(a); mpc_clear(b); return 0; }
