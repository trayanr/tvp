#include <concepts>
#include <ranges>
#include <span>
#include <vector>
#include <iostream>

template<std::integral T> constexpr T twice(T n) { return n + n; }
static_assert(twice(21) == 42);
static_assert(std::ranges::contiguous_range<std::span<int>>);
int main() {
    std::vector<int> values{1, 2, 3, 4, 5, 6};
    std::span<int> view(values);
    int sum = 0;
    for (auto n : view | std::views::filter([](int n) { return n % 2 == 0; })
                       | std::views::transform([](int n) { return twice(n); }))
        sum += n;
    if (sum != 24 || view.subspan(2, 2)[1] != 4) return 1;
    std::cout << "C++20 concepts/span/ranges: PASS\n";
}
