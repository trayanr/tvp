#include <isl/cpp.h>
#include <iostream>
#include <stdexcept>

static void require(bool ok) { if (!ok) throw std::runtime_error("semantic mismatch"); }
int main() {
    isl_ctx *raw = isl_ctx_alloc();
    if (!raw) return 1;
    {
        isl::ctx ctx(raw);
        isl::set domain(ctx, "{ [i] : 0 <= i <= 4 }");
        isl::map transform(ctx, "{ [i] -> [j] : j = 2*i+1 }");
        require(domain.apply(transform).is_equal(isl::set(ctx, "{ [j] : 1 <= j <= 9 and j % 2 = 1 }")));
        isl::map choices(ctx, "{ [i] -> [j] : 0 <= i <= 4 and i <= j <= i+2 }");
        require(choices.lexmin().is_equal(isl::map(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = i }")));
        require(choices.lexmax().is_equal(isl::map(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = i+2 }")));
        require(domain.subtract(domain).is_empty());
    }
    isl_ctx_free(raw);
    std::cout << "PASS C++ set image, lexopt and empty difference\n";
}
