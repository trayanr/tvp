#include <gmpxx.h>
#include <stdexcept>
#include <iostream>
#include "value.h"
int main() {
    mpz_class x = 1; x <<= 256;
    if (sqrt(x*x) != x) return 1;
    try { throw std::runtime_error("owned"); }
    catch (const std::runtime_error &e) { std::cout << "C++ " << e.what() << " " << VALUE << "\n"; }
}
