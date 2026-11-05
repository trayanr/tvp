#include <gmpxx.h>
#include "gnu-target-maps.h"
int main() {
    mpz_class modulus = 1;
    modulus <<= 521;
    modulus -= 1;
    mpz_class value = 65537, inverse;
    if (!mpz_invert(inverse.get_mpz_t(), value.get_mpz_t(), modulus.get_mpz_t())) return 1;
    if ((inverse * value) % modulus != 1) return 2;
    mpz_class square = modulus * modulus;
    if (sqrt(square) != modulus) return 3;
    target_maps(1, 1);
    puts("Static GMP/GMPXX arithmetic OK");
}
