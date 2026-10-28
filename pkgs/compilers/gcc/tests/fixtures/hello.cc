#include <iostream>
#include <stdexcept>
#include <vector>
int main() {
    std::vector<int> values{19, 23};
    try { throw std::runtime_error("tvp"); }
    catch (const std::runtime_error&) { std::cout << values[0] + values[1] << '\n'; }
}
