#include <mpfr.h>
#include <stdio.h>
#include <string.h>
int main(void) { if(strcmp(MPFR_VERSION_STRING, mpfr_get_version())) return 1; puts(mpfr_get_version()); return 0; }
