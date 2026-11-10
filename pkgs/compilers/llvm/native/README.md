LLVM 23.1.4 uses an independent native procedure on the source-GNU candidate
base, only for the ordinary x86_64-linux row. `legacy.nix` captures the complete
prior factory for retained and historical construction consumers.

The base compiler builds LLVM. Installed Clang independently targets the selected
raw GCC installation, matching GCC/C++ runtime outputs, libc, Binutils and loader.
The defaults select public GCC 16, public libc 2 and public Binutils 2. The linked
LLVM/Clang libraries still use the build base and explicit linked dependencies;
this does not grant the build closure permission as an installed runtime.

The installer exposes a small GCC layout view for Clang: matching intrinsic and
C++ headers alongside the selected startup objects and runtime archives. Provider
files remain unchanged. Distinct runtime outputs must be disjoint or agree on
shared files, so library search order cannot silently select another provider.
The wrapper classifies option operands and GNU response files, and consumes
NIX_CFLAGS_COMPILE, NIX_CFLAGS_LINK and raw NIX_LDFLAGS in their relevant modes.
Explicit response-quoting overrides and mode-changing link flags are rejected.
The native GNU wrapper preserves C++, preprocessing and ordinary compiler aliases.
The clang-cl alias retains the upstream CL frontend directly; it uses the caller's
explicit target/SDK inputs, not the GNU wrapper's NIX flag/sysroot protocol. Its
frontend presence does not certify a Windows SDK, linker or runtime.

All upstream target backends, Clang/LLD, shared libraries, RTTI and mandatory
zlib/zstd/libxml2/FFI support remain enabled. Assembler and Bitcode llvm-lit checks
are mandatory build steps. Sed, Grep and Diffutils are explicit build tools for
upstream configure and test commands. The regular package tests use the owned test
context and bind their loader expectation to the effective specification.

Installed qualification includes all package controls, the upstream
Assembler/Bitcode suites, actual driver aliases and runtime/provider audits.
Pure contracts and retained-tool fixtures do not replace those installed checks.
HARDENING-GATE-1 remains OPEN_UNWAIVED; no security-equivalence claim is made.
