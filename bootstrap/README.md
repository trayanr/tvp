# Standalone construction through GCC10

This private x86_64 Linux entrypoint constructs GCC 10.4.0 C and C++ with an
owned wrapper and static target libstdc++, from one **229-byte AMD64 hex0 seed**.
It is an intermediate compiler milestone, not a complete modern TVP base. The catalogue,
default base and frozen construction remain separate and unchanged.

```sh
nix build --file bootstrap bzip2 --no-link -L
nix build --file bootstrap gnutar-latest --no-link -L
nix build --file bootstrap gcc10-unwrapped --no-link -L
nix build --file bootstrap gcc10 --no-link -L
nix build --file bootstrap tests.gcc10-archives 'tests.gcc10^*' --no-link -L
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
