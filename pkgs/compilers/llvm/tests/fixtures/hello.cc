#include <iostream>
#include <vector>
#include <numeric>
int main() { std::vector<int> values{20,22}; std::cout << std::accumulate(values.begin(),values.end(),0); }
