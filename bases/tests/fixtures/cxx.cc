#include <iostream>
#include <stdexcept>
#include <vector>
int main() {
    const std::vector<int> values(2, 21);
    try { throw std::runtime_error("test"); }
    catch (const std::exception&) { std::cout << values[0] + values[1] << '\n'; }
}
