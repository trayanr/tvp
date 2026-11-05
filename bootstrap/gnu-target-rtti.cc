#include <stdexcept>
#include <string>
#include <typeinfo>
#include "gnu-target-rtti.h"
#include "gnu-target-maps.h"
int main() {
    TargetBase *b = target_new();
    auto d = dynamic_cast<TargetDerived *>(b);
    if (!d || d->value != 42 || typeid(*b) != typeid(TargetDerived)) return 1;
    delete b;
    try { target_raise(); return 2; }
    catch (const std::runtime_error &e) { if (std::string(e.what()) != "capability ABI") return 3; }
    target_maps(1, 1);
}
