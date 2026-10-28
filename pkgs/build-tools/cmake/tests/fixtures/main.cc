#include <iostream>
extern "C" int answer(void);
int main() { std::cout << answer(); return answer() != 42; }
