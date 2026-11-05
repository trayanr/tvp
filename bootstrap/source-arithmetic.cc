#include <gmpxx.h>
#include <stdexcept>
#include "source-arithmetic.c"
int main() {
    mpz_class a = 1;
    a <<= 1024;
    a -= 1;
    mpz_class square = a * a;
    if (sqrt(square) != a) return 1;
    try { throw std::runtime_error("owned unwinder"); }
    catch (const std::runtime_error &e) { if (strcmp(e.what(), "owned unwinder")) return 2; }
    arithmetic(); mappings(); puts("C++ arithmetic OK");
}
