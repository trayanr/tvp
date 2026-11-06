#include <gmpxx.h>
int main() { mpz_class a = 123456789; a *= a; return a != mpz_class("15241578750190521"); }
