#include <vector>
extern "C" int cppanswer(void) {
    const std::vector<int> values{20, 22};
    return values.at(0) + values.at(1);
}
