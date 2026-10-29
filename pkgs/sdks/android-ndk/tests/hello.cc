#include <iostream>
#include <thread>
int main() { std::thread work([] { std::cout << "TVP"; }); work.join(); }
