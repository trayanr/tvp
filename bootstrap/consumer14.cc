#include <algorithm>
#include <memory>
#include <utility>
#include <map>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <vector>
#include <iostream>

extern "C" int c_sum(const int *, int);
static int destroyed = 0;
struct Guard { ~Guard() { ++destroyed; } };
struct Base { virtual ~Base() {} };
struct Derived : Base { int value() const { return 42; } };

constexpr int sum_to(int n) {
    int result = 0;
    for (int i = 1; i <= n; ++i) result += i;
    return result;
}
template<class T> constexpr T answer = T(42);
auto deduced() { return answer<int>; }
template<int... I> int sequence_sum(std::integer_sequence<int, I...>) {
    int values[] = { I... };
    return c_sum(values, sizeof...(I));
}
static_assert(sum_to(6) == 21, "C++14 relaxed constexpr");
static_assert(answer<long> == 42, "C++14 variable templates");

int main() {
    auto add = [](auto a, auto b) { return a + b; };
    auto owned = std::make_unique<int>(deduced());
    if (add(*owned, 8) != 50 || sequence_sum(std::make_integer_sequence<int, 5>{}) != 10)
        return 5;
    std::vector<int> v;
    v.push_back(3); v.push_back(1); v.push_back(2);
    std::sort(v.begin(), v.end());
    std::map<std::string, int> m;
    m["sum"] = c_sum(&v[0], v.size());
    if (v[0] != 1 || m["sum"] != 6) return 1;
    try {
        Guard g;
        throw std::runtime_error("unwind");
    } catch (const std::exception &e) {
        if (std::string(e.what()) != "unwind" || destroyed != 1) return 2;
    }
    Derived d;
    Base &b = d;
    if (typeid(b) != typeid(Derived) || dynamic_cast<Derived &>(b).value() != 42) return 3;
    Base plain;
    try { (void)dynamic_cast<Derived &>(plain); return 4; }
    catch (const std::bad_cast &) {}
    std::cout << "C++14 constexpr/lambdas/returns/variable templates/make_unique/integer_sequence, STL/templates, exceptions/unwind, RTTI, C ABI: PASS\n";
    return 0;
}
