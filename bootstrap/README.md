# Standalone construction through GCC16

This private x86_64 Linux entrypoint constructs GCC 16.2.0 C and C++ with an
owned wrapper and matching split static libgcc/libstdc++, from one **229-byte AMD64 hex0 seed**.
It is an intermediate compiler milestone, not a complete modern TVP base. The catalogue,
default base and frozen construction remain separate and unchanged.

```sh
nix build --file bootstrap bzip2 --no-link -L
nix build --file bootstrap gnutar-latest --no-link -L
nix build --file bootstrap gcc10-unwrapped --no-link -L
nix build --file bootstrap gcc10 --no-link -L
nix build --file bootstrap tests.gcc10-archives 'tests.gcc10^*' --no-link -L
nix build --file bootstrap gcc16-gmp gcc16-mpfr gcc16-mpc gcc16-libbacktrace gcc16-libiberty --no-link -L
nix build --file bootstrap gcc-latest-unwrapped --no-link -L
nix build --file bootstrap gcc16-libgcc --no-link -L
nix build --file bootstrap gcc16-libstdcxx --no-link -L
nix build --file bootstrap gcc-latest 'tests.gcc16^*' --no-link -L
python3 bootstrap/audit.py > executable-inputs.json
```

## Construction boundary

The only native binary input is the pinned seed in `provenance.json`. Nix's
builtin downloader fetches it and pinned source/patch data. Its builtin tarball
fetcher obtains six source-only Stage0 components at the release's gitlink
revisions. Recursive source-tree/seed hashes and flat archive/patch hashes are
distinguished. No seed repository bundle of other prebuilt binaries is imported.

`adapter.nix` uses `builtins.derivation`, with empty PATH by default. Builders
select declared source-built Kaem or Bash interpreters. Generated scripts retain
source contexts. Later PATH, compiler tools, headers, libraries and loaders come
from declared earlier stages. Source-built stages disable substitution. Nix's
evaluator, downloader, store/daemon, sandbox and the host Linux kernel remain
explicit boundaries. No 32-bit ABI or emulator is required.

The original Stage0/Mes/TinyCC/Mes libc construction and its `compiler`, `libc`,
`tests.consumer` and `tests.versions` exports remain controls. The extension adds
Patch, Make, Coreutils and Bash, then Mes-compatible text/archive tools. Both
musl/TinyCC transitions are retained before the musl GNU tool floor. TinyCC's
musl builds omit complex sources, use C math fallbacks and disable TLS; those
limitations end at the GCC-built musl stage. GCC 4.6 C builds the full musl,
then the C+C++ rebuild uses private GMP 4.3.2, MPFR 2.4.2 and MPC 1.0.3.
The C++ recipe uses the full default make target with shared libraries disabled.

The next private endpoints add bzip2 1.0.8, Tar 1.35, `gcc10-unwrapped` and `gcc10`.
Tar explicitly selects musl's separate wrapper output. Bzip2 retains its archive
binaries and omits optional host-dependent pager/grep/diff scripts. GCC10 uses
in-tree GMP 6.2.1 (the last supporting GCC4.6), MPFR 4.2.2 and MPC 1.4.1, without
ISL. The pinned recipe deliberately avoids GCC10.5 (GCC bug 110716). Host code uses
O1 and target code O0. Bootstrap self-comparison, analyzer, decimal float, shared
libraries, LTO, multilib, plugins, NLS, optional runtimes and filesystem TS are
disabled. Installation merges lib64 into lib and links lib64 to lib.

The owned GCC10 wrappers preserve argument boundaries, use the fixed native
store for RPATH selection even with empty `NIX_STORE`, and retain libtool's `-v`
special case. C++ headers precede libc for include_next; musl's -B precedes
libgcc for gnulib detection. Static libstdc++ adds no compiler RPATH.

The explicit native tuple is `x86_64-unknown-linux-musl`. Old config.sub handling
retains upstream's reduced tuple where necessary. GCC's driver library searches,
assembler/linker paths and loader defaults are bound to owned stages, alongside
upstream's no-system-headers patch and libstdc++ `os/generic` adjustment. The
first GCC C stage has only the static transitional libc; dynamic consumers use
the later GCC-built musl. Installed maintenance scripts use an owned interpreter;
the unneeded Bash bug-report mailer is omitted.

## Evidence and limits

Recipes are adapted from nixpkgs revision
`97059e5ecd707df94f104cfd77b0ac0e2c14881c`, without importing its scope or package
set. `COPYING.nixpkgs`, `COPYING.GPL3`, per-file notices, `recipe-sources.json` and
`provenance.json` retain attribution, licenses and exact upstream identities.
The original Mes wait-status initialization is unchanged.

`tests.cxx` compiles and runs C++98 STL/templates, exceptions with destructor
unwinding, RTTI and a separately compiled C object in an empty environment with
explicit owned inputs. It checks fully static and dynamic-musl executables with
static libstdc++/libgcc. `tests.libc` probes allocation, conversion, math, errno,
TLS, shell spawning and word expansion on GCC-built musl. Tool-function checks exercise patch,
make/shell selection, text processing, search and archive/compression roundtrips.
Upstream transition tests are retained, with musl's wrapper output selected
explicitly. Their C hello program is not a C++ test.

`tests.gcc10` exercises raw and wrapped C/C++14 in an empty environment: relaxed
constexpr, generic lambdas, deduced returns, variable templates, make_unique and
integer_sequence, alongside STL, exceptions/unwinding, RTTI and separate C-object
ABI linkage. Static and dynamic-musl consumers use static libstdc++/libgcc.
Search directories, specs, selected assembler/linker and archives are inspected.
`tests.gcc10-archives` checks bzip2 roundtrips and gzip/bzip2/xz Tar extraction,
including executable mode, mtime and execution. Runtime compiler checks are
explicit opt-in targeted builds; ordinary CI runs only offline contracts.

`tests.stage-comparison` records adjacent TinyCC compiler and C-object byte
comparisons. The original version chain only executes compiler versions. Neither
is a fixed-point, diverse-compilation, reproducibility or upstream conformance
proof. Mes libc remains transitional with limited POSIX coverage.

Python, readelf and the Nix CLI used by the observer audits are never bootstrap
build inputs. `audit.py` recursively classifies seed, source and executable
origins, pins, builders, PATH and shell edges; it rejects unknown or escaping
inputs. `runtime-audit.py` takes that report, an observer readelf path and realized
output roots to inspect ELF loaders/libraries, script interpreters and symlinks.
ELF architecture uses numeric e_machine 62. Runtime source-text references are
classified separately from executables; early-chain executable roots are forbidden
in runtime closures while remaining valid construction inputs.
The offline `bootstrap-audit-contracts` repository check does not compile these
stages; compiler/runtime realization is separate targeted evidence.

`negative.nix` preserves the earlier expected-failure controls. GCC10 capability
probes are bounded, with no upstream GCC/libstdc++ conformance claim. A modern
compiler, later-generation comparisons, complete owned tools/base construction
and coherent candidate/catalogue validation remain necessary before proposing
any default-base change.

## Modern native-musl checkpoint

The exact construction pin selects GCC 16.2.0, independently of the ordinary
catalogue's moving compiler selector. Private `gcc16-gmp` (6.3.0, assembly disabled,
M4=false), `gcc16-mpfr` (4.2.2), `gcc16-mpc` (1.3.1), `gcc16-libbacktrace` and PIC
`gcc16-libiberty` use GCC10. Both compiler roles of `gcc-latest-unwrapped` use
GCC10; all three binutils roles use the existing owned binutils. The common GCC
source applies the pinned regular-directory and skip-target-library patches.
The compiler stage skips target libraries; separate `gcc16-libgcc` and
`gcc16-libstdcxx` build static archives with the new compiler and GCC-built musl.
`gcc-latest` assembles them through the existing hardened wrapper/scripts.

The raw GCC16 driver (`gcc/gcc.cc`) binds sysroot, headers, default startfile and
library searches, assembler/linker and every loader alternative to owned stages.
Compiler host code uses O1; split target runtime code uses O0. C/C++ only,
disabled bootstrap/analyzer/LTO/plugins/ISL/multilib/NLS and upstream's bounded
compiler-stage configuration are retained. Installed compiler maintenance tools
are omitted as unused; helper/runtime configure and copied source subtrees are
pruned after installation. Public headers (including .tcc), static archives and
licenses remain. Native musl uses `os/generic` without a fake glibc tuple link.

`tests.gcc16` explicitly supplies split runtime/header paths to raw compiler
probes. In an empty environment with declared owned tools it checks exact
version/tuple, C compile/link/run, separately compiled C-object ABI, retained
C++14/STL/templates/exceptions/destructor unwinding/RTTI and bounded C++20
concepts/span/ranges. Fully static and dynamic-musl executables use static GCC/C++
runtimes. It inspects specs, search directories, selected tools/archives/headers
and ELF interpreters, dependencies and runtime paths, and exercises comma paths
with empty/hostile NIX_STORE. Observer runtime audits independently inspect numeric
ELF architecture, closure provenance, loaders, symlinks and script interpreters.
GMP/MPFR/MPC `make check` suites pass and retain separate `checks` outputs.
Libiberty checks pass; libbacktrace checks record failure because the upstream
suite requests disabled LTO. Their logs and exit codes are separate `checks`
outputs; helper check failures are evidence, not a conformance gate. No borrowed
DejaGNU/Tcl/Expect is introduced: GCC/libstdc++ conformance is not claimed.

This is an opt-in musl compiler checkpoint. It does not establish the complete
owned default base or a matching current GNU catalogue base. Later work needs
modern compiler/libc/tool rebuild comparisons and a source-built headers/libc/
sysroot transition for that GNU base, or explicit review of a coherent musl base
candidate. Complete candidate review and catalogue validation precede any default
switch. `--disable-bootstrap` provides no self-comparison, DDC or reproducibility
proof. Historical failures and strict=false conformance evidence remain unwaived.

## Private GNU build prerequisites

`linux-headers` exports sanitized Linux 6.9 x86 userspace headers and separate
license/exception texts. Its host generators use the owned GCC16 wrapper and
Bash. `make headers` needs neither rsync nor Perl for this selected target.
`build-m4` (1.4.21), `build-bison` (3.8.2), `build-python` (3.12.5) and
`build-grep` (3.12) use that existing compiler and the sufficient owned tool floor.
These helpers are musl-hosted; their names make no static-linkage claim. Headers
are source data, distinct from executable build dependencies.

```sh
nix build --file bootstrap linux-headers 'build-m4^*' 'build-bison^*' --no-link -L
nix build --file bootstrap build-python 'build-grep^*' --no-link -L
nix build --file bootstrap 'tests.prerequisites^*' --no-link -L
```

M4 binds its syscmd shell. Bison binds M4 and retains its installed skeletons;
yacc uses owned Bash. Grep's egrep/fgrep bind both Bash and the selected grep.
Release configure/parser timestamps survive extraction. Native M4/Bison/grep
checks retain their actual logs and exit status in separate `checks` outputs;
these evidence outputs do not imply a strict complete-suite pass. The opt-in
functional contracts independently require header compilation, M4 shell/macro
expansion, compiled Bison/yacc parsers and grep modes/status/argument handling.

Python adapts the existing TVP 3.12.5 minimal profile, not upstream's 3.14 recipe.
It disables the listed external extension modules, ensurepip installation,
readline and test extension modules. It binds build/install make shells,
subprocess's default shell, installed entrypoints and python-config helpers;
compileall uses the declared per-build CPU allocation. Its supported scope is
build scripts, with temporary-file/subprocess and module-absence contracts.
`os.system()` remains unsupported because libc selects `/bin/sh`; the selected
glibc 2.39 Python scripts do not call it. The tests run actual glibc script help
and constant-generation fixtures with the owned compiler, without building libc.
`prerequisite-sources.json` records each file's real origins and adaptations.

These private opt-in endpoints do not extend the normal catalogue, change a
base, establish GCC16/glibc2.39 compatibility, or complete GNU construction.
A GNU-target compiler/core-libgcc bridge, libc/sysroot, matching GNU runtimes,
GNU-hosted compiler and a complete candidate base still require implementation
and validation. Existing compiler and frozen catalogue identities remain controls.

The private GNU checkpoint is opt-in through `gnu-gcc` (wrapped),
`gnu-gcc-unwrapped`, `gnu-libc`, `gnu-libgcc`, `gnu-libstdcxx`, and
`gnu-tests`. `gnu.nix` keeps the ABI roles local: M is
`x86_64-unknown-linux-musl`, G is `x86_64-unknown-linux-gnu`. The M/M/G
compiler has an empty target sysroot. It constructs glibc 2.39 against the
unchanged Linux 6.9 headers; its temporary arithmetic archive and CRT bridge
are construction inputs only. Proper G core libgcc, static EH, shared
unwinding and static/shared C++ runtimes are built separately with POSIX
threads. GNU-host math libraries, Bash and binutils 2.42 precede the M/G/G
compiler. Build generators and their archive remain M.

GNU source and loader configuration never change the musl recipes. The raw
GNU driver binds its sysroot, runtime libraries and GNU assembler/linker;
the wrapper binds GNU Bash/tools and preserves argument boundaries. Transitive
RPATH supplies glibc's cancellation unwinder without `LD_LIBRARY_PATH`.
`gnu-origin-audit.py` classifies the entire construction graph;
`gnu-runtime-audit.py` requires an exact GNU profile, excludes construction
outputs, distinguishes executable outputs from source data, and checks actual
loader resolution. `gnu-sources.json` records pins and adaptations.

This is a reduced bootstrap GNU sysroot: generated locales, gconv modules,
installed libc tools, nscd, timezone tools, profiling and mathvec are omitted.
Libc shell APIs using `/bin/sh` are outside this profile. Multilib and alternate
libc modes are unsupported; the wrapper rejects them. LTO, plugins and ISL are
disabled. Scoped probes cover native execution, dynamic/static C and C++14,
explicit PIE, C++20, shared ABI, pthread/TLS, dlopen and cancellation unwinding.
They do not establish full GCC/glibc conformance, self-comparison, DDC,
reproducibility, a complete base or a default change. A later G/G/G generation
and parent review/publication/CI gates remain separate.
