#include <algorithm>
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

int main() {
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
    std::cout << "C++98 STL/templates, exceptions/unwind, RTTI, C ABI: PASS\n";
    return 0;
}
