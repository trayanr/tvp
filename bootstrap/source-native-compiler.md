# Opt-in native compiler checkpoint

`import ./source-native-compiler.nix { }` exposes a separate GCC 16.2.0 raw
`compiler`, hardened `driver`, and reconstructed `composition`. The composition
uses `source-base.nix { compiler = driver; }`; its base, environment and ordinary
builder consumers therefore capture the selected compiler. No catalogue or
public/default selector changes.

The compiler recipe is an owned `tvp.builder` plan with explicit prepare,
configure, build and install steps, lowered directly to `builtins.derivation`.
Build, host and target are `x86_64-unknown-linux-gnu`. Both host compilation and
build generators explicitly use the capability source-base driver. New native
libiberty (including PIC archive and headers) and libbacktrace use that same base.
GMP 6.3.0, MPFR 4.2.2 and MPC 1.4.1 retain their source-consumer identities.

Source preparation starts from the pinned GCC archive, the existing regular
layout patch and target-library configure hook. It removes implicit `/usr/lib`
startup lookup, binds GNU loader definitions to the capability libc, and binds
shell scripts to the declared source shell. It does not reuse the source prepared
for the earlier libc profile. Both libc profiles are glibc 2.39.

The capability libc, libgcc and libstdc++ are reused. GNU-hosted Binutils 2.42,
Bash and other existing build tools retain their earlier executable generations;
they are explicit tools, not permissions for the new compiler's loader/runtime.
The completed owned Python, Make, Ninja, CMake and Perl tools are reused without
rebuilding them. Source preparation uses Python; GCC installation uses Tar/Perl.

Feature policy deliberately follows the earlier reduced compiler checkpoint:
C/C++, POSIX threads, no bootstrap comparison, multilib, NLS, analyzer, decimal
float, gcov, libssp, plugins, LTO, included gettext or ISL. Only the compiler is
built (`all-gcc`), using the matching existing target libraries, with `-O1` host
and generator compilation. This is not canonical full GCC parity. No Texinfo,
Tcl, Expect or DejaGNU prerequisites are introduced. Full canonical feature/test
parity is a later gate before default migration.

`source-native-driver.nix` derives effective specs from the new installed raw
compiler and uses the existing hardened `gnu-environment-wrapper.sh` parser. It
retains operand/response-file/NIX flag ordering, effective `-dumpspecs`, ABI
rejections and the explicit unsupported static-PIE rejection. Installed runtime
include symlinks point to the selected libgcc headers.

Focused validation lives in `source-native-compiler-tests.nix`. Its target probe
reuses `gnu-target-checks.py` and fixtures, including raw logs and negative
controls. Its project checks raw C/C++14/C++20 modes, installed GMP/MPFR/MPC,
Make/Ninja CMake generators, a compiled native generator, rebuild/no-op/install,
and actual selected compiler identities. Constructor/edit assertions include an
unusable replacement compiler to expose fallback. These are bounded tests, not
fresh DejaGNU coverage or a compiler conformance claim.

Support check evidence is explicit. Libiberty records raw `make check` output.
Libbacktrace's unrestricted check attempts `btest_lto` with the LTO-disabled
compiler and returns nonzero. A separate `supportChecks` output runs the upstream
checks with only generated `am__EXEEXT_6`/`am__append_10` (the unconditional LTO
case) excluded; its raw status and every upstream `.log`/`.trs` remain separate.
No canonical GCC failure allowance applies to this checkpoint.

Origin and runtime auditors require the previous strict auditors before extending
their results. The new compiler ELF permission set excludes earlier tool libc
and compiler generations, independently of the larger development reference
closure. Runtime checks include actual loader resolution, held frontend process
maps and generator ELF/loader evidence. Review the immutable implementation
handoff for concrete output identities, counts, failed attempts and limitations.

Parent owns source review, publication, CI and merge. Comparative readability
review, later compiler stages, full parity and any catalogue/default migration
remain outside this checkpoint. No selfhosting, fixed point, reproducibility,
DDC or machine readiness claim is made.

Raw GCC's `-dumpspecs` retains upstream builtin-query semantics; installed raw
specs and real link traces are checked separately. The hardened driver exposes
the effective selected spec file, including when queried through response files.

The rebinding fixtures execute logging delegators over the selected new driver
through constructor, base, environment and step edits. Their separate evidence
contains actual compiler calls and CMake caches. Native loader observations also
separate the `collect2` process from its reused Binutils linker child.
