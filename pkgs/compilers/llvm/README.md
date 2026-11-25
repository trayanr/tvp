# Historical LLVM JIT providers

The LLVM 11.1.0 and 14.0.6 monorepo releases install Clang, LLD, LLVM's
shared library, headers, and llvm-config. LLVM 11 exposes ORC v1,
which early PostgreSQL 11 and 12 releases call. LLVM 14 supplies the
ORC v2 interface and the minimum LLVM version required by PostgreSQL 18.
The installed JIT check uses the selected API to compile and call a
function from an LLVM IR module.

The historical procedure enables FFI, zlib, and libxml2. LLVM did not
introduce optional Zstandard support until 15. Libedit, libpfm,
and Z3 need source-owned providers for the corresponding features.
The released LLVM sources have known GCC 13 header-compatibility gaps,
so they use the source-owned GCC 9.5 construction base. The installed
Clang selects its independent GCC 13 target runtime through the
explicit GCC toolchain layout.

Both source tarballs were checked with Tom Stellard's signing key from
the [LLVM release keyring](https://releases.llvm.org/release-keys.asc).
The LLVM 11 CMake project declares a 3.4.3 minimum. The historical
procedure sets CMake's compatibility policy floor to 3.5 for the
current TVP CMake provider. It selects Python 3.11 for installed
utilities that still import `imp` and `distutils`.

Older LLVM and Clang releases require a separate source-layout audit.
The archive name and split between the LLVM, Clang, and LLD source
tarballs varies by release. The [LLVM release archive](https://releases.llvm.org/)
also includes releases absent from the current tag-based issue inventory.
