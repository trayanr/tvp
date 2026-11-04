Patchelf retains one installation stage and uses the completed base's different
Patchelf for output finalization. Its C++ runtime is the actual selected GCC16
compiler output, which contains libstdc++ and libgcc_s.

The full archive suite reports 65 PASS, four SKIP and two FAIL. The no-rpath and
shared-rpath fixtures assume NIX_DONT_SET_RPATH suppresses wrapper paths. The
owned compiler wrappers always add their native paths, so those fixture
preconditions are false. The check requires these exact failures and verifies
the actual paths; it does not mark them PASS. Two MIPS dynamic-tag tests and a
32-bit test skip upstream. The short-first-segment test checks for amd64 while
the native kernel reports x86_64, so its upstream skip is retained.
