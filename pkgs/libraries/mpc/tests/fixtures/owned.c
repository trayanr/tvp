#include <stdio.h>
#include <string.h>
#include <mpc.h>

/* MPC calls only: do not give the executable a direct MPFR/GMP dependency. */
int main(void) {
    mpc_t z, conjugate, product;
    mpc_init2(z, 128);
    mpc_init2(conjugate, 128);
    mpc_init2(product, 128);
    if (strcmp(mpc_get_version(), MPC_VERSION_STRING)) return 1;
    mpc_set_ui_ui(z, 3, 4, MPC_RNDNN);
    mpc_conj(conjugate, z, MPC_RNDNN);
    mpc_mul(product, z, conjugate, MPC_RNDNN);
    if (mpc_cmp_si_si(product, 25, 0)) return 2;
    /* 1/3 rounded upward and downward at low precision must differ. */
    mpc_set_prec(z, 8);
    mpc_set_prec(conjugate, 8);
    mpc_set_ui(z, 1, MPC_RNDNN);
    mpc_set_ui(conjugate, 1, MPC_RNDNN);
    mpc_div_ui(z, z, 3, MPC_RNDUU);
    mpc_div_ui(conjugate, conjugate, 3, MPC_RNDDD);
    if (mpc_cmp(z, conjugate) <= 0) return 3;
    mpc_clear(product);
    mpc_clear(conjugate);
    mpc_clear(z);
    puts("ok");
    return 0;
}
