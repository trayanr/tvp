#include <stdexcept>
#include "gnu-target-rtti.h"
extern "C" TargetBase *target_new() { return new TargetDerived; }
extern "C" void target_raise() { throw std::runtime_error("capability ABI"); }
