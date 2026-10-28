#include <iostream>
#include <numeric>
#include <vector>
int main() {
    std::vector<int> values{19, 23};
    std::cout << std::accumulate(values.begin(), values.end(), 0) << '\n';
}
