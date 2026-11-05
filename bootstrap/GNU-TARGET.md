# Capability-libc GNU target (opt-in)

`gnu-target-profile.nix` exposes `libc`, `libgcc` and `libstdcxx` separately.
Build `libgcc` directly, then `libstdcxx` directly. Both runtime recipes use the
existing musl-hosted GNU cross compiler and pinned GCC source. The first uses
the arithmetic bridge; the second uses the new libgcc. Neither builds GCC
frontends. Shared/static libgcc, real EH archives, public unwind/thread headers,
and shared/static libstdc++ are retained.

`gnu-target-driver.nix` configures the unchanged GNU-native raw compiler for
these target outputs. The compiler executables and intrinsic headers remain
prior-generation host roles. A separate prefix supplies the new CRT and
runtime files. The complete installed GCC specs are rebound, including the
loader, sysroot and runtime search paths. Default C++ headers are suppressed;
selected C++ headers precede intrinsic and libc headers. GCC still chooses the
frontend for each input language, including mixed inputs and `-x`.

Supported ordinary modes include preprocessing, dependencies, assembly,
compilation, dynamic/static/shared links, PIE/no-PIE, pthread, rdynamic,
nostdlib/nostartfiles/nodefaultlibs and target file queries. The existing literal
NIX flag and response-file protocol is reused. Static PIE, alternate ABIs
(including 16-bit mode), and nonempty hardening requests reject explicitly.
This is a native x86_64 target adapter, not a complete GCC CLI compatibility or
compiler self-hosting claim. Explicit user include/library flags remain GCC
customization; they are not an arbitrary-shell security boundary.

`gnu-target-environment.nix` supplies separate base DATA and explicit target
`runtimeDirectories`, without a package-set, setup script or mkDerivation.
`gnu-target-tests.nix` uses the actual owned builder for public library discovery,
flags, customization and installed C-only cancellation. Its `probe` endpoint
checks queries, includes/CRT/link traces, ELF modes, loader resolution, STL/C++20,
UTF-8 locale/multibyte behavior, threads, cross-DSO exceptions/RTTI and forced
unwinding. Five unmodified libstdc++ compile/run tests are a focused subset,
not a full DejaGNU or conformance result. Evidence is a separate named output.

C-only cancellation loads libgcc through libc rather than DT_NEEDED. The
installed fixture uses explicit `dlopenDirectories` and the additive
`builder.outputs.rpaths { forceRpath = true; ... }` option. This runs the existing
provider/shrink algorithm, then preserves a transitive DT_RPATH for that lookup.
The option requires explicit dlopen directories and the owned base/libraries
form. Existing callers retain their exact command and derivation identities.

`gnu-target-origin-audit.py` extends the existing construction ledger with
validated owned runners and a finite source-only probe tree. It preserves all
425 prior construction nodes and 59 runner profiles. `gnu-target-runtime-audit.py`
uses the existing strict per-generation auditor: new target ELFs resolve new
libraries, while the capability libc's prior GNU shell uses its old runtime.
Source data never authorizes executables. The host compiler, musl construction
tools and target runtime have distinct roles; old paths are not globally banned
from legitimate host and prior-shell closures.

No default, frozen checkpoint, catalogue selector or public base changes.
Earlier Patchelf/GCC/glibc failures and exclusions remain qualified; this work
transfers no full-conformance claim. Full native compiler generations and
independent base composition remain later work.
