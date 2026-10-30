#include <stdio.h>
#include <mpc.h>
#include <string.h>
int main(void) { if(strcmp(MPC_VERSION_STRING, mpc_get_version())) return 1; puts(mpc_get_version()); return 0; }
