LLVM 23.1.4 uses an independent native procedure on the source-GNU candidate
base, only for the ordinary x86_64-linux row. `legacy.nix` captures the complete
prior factory for retained and historical construction consumers.

The base compiler builds LLVM. Installed Clang independently targets the selected
raw GCC installation, matching GCC/C++ runtime outputs, libc, Binutils and loader.
The defaults select public GCC 16, public libc 2 and public Binutils 2. The linked
LLVM/Clang libraries still use the build base and explicit linked dependencies;
this does not grant the build closure permission as an installed runtime.

All upstream target backends, Clang/LLD, shared libraries, RTTI and mandatory
zlib/zstd/libxml2/FFI support remain enabled. Assembler and Bitcode llvm-lit checks
are mandatory build steps. The seven regular package tests use the owned test
context and bind their loader expectation to the effective specification.

This is SOURCE STAGE ONLY. Pure provider/customization contracts, mock wrapper
argument tests and tiny cached-GCC ELF fixtures do not qualify installed LLVM.
LLVM configure/build/install, its seven installed controls and actual upstream
checks require parent independent review and separate authorization to run.
HARDENING-GATE-1 remains OPEN_UNWAIVED; no security-equivalence claim is made.
