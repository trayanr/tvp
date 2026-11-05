struct TargetBase { virtual ~TargetBase() = default; };
struct TargetDerived : TargetBase { int value = 42; };
extern "C" TargetBase *target_new();
extern "C" void target_raise();
