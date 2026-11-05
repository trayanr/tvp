#include <stdexcept>
static int destroyed;
struct Guard { ~Guard() { ++destroyed; } };
extern "C" void raise_exception() {
    Guard guard;
    throw std::runtime_error("shared GNU ABI");
}
extern "C" int destructor_count() { return destroyed; }
