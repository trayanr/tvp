#include <hwy/contrib/sort/vqsort.h>
#include <hwy/targets.h>
#include <hwy/tests/test_util.h>

#include <cstdint>
#include <cstdio>

int main() {
    if (hwy::SupportedTargets() == 0) {
        return 1;
    }
    std::uint32_t values[] = {9, 3, 7, 3, 1};
    const std::uint32_t expected[] = {1, 3, 3, 7, 9};
    hwy::VQSort(values, sizeof(values) / sizeof(values[0]), hwy::SortAscending{});
    if (!hwy::BytesEqual(values, expected, sizeof(expected), nullptr)) {
        return 1;
    }
    std::puts("Highway dispatch");
    return 0;
}
