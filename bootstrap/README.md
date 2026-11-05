# Standalone construction through first C++

This private x86_64 Linux entrypoint constructs GCC 4.6.4 C and C++, including
static target libstdc++, from one **229-byte AMD64 hex0 seed**. It is an
intermediate compiler milestone, not a complete modern TVP base. The catalogue,
default base and frozen construction remain separate and unchanged.

```sh
nix build --file bootstrap gcc46-cxx --no-link -L
nix build --file bootstrap tests.cxx tests.libc tests.tools tests.transitions tests.stage-comparison --no-link -L
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

`tests.stage-comparison` records adjacent TinyCC compiler and C-object byte
comparisons. The original version chain only executes compiler versions. Neither
is a fixed-point, diverse-compilation, reproducibility or upstream conformance
proof. Mes libc remains transitional with limited POSIX coverage.

Python, readelf and the Nix CLI used by the observer audits are never bootstrap
build inputs. `audit.py` recursively classifies seed, source and executable
origins, pins, builders, PATH and shell edges; it rejects unknown or escaping
inputs. `runtime-audit.py` takes that report, an observer readelf path and realized
output roots to inspect ELF loaders/libraries, script interpreters and symlinks.
Runtime source-text references are classified separately from executables.
The offline `bootstrap-audit-contracts` repository check does not compile these
stages; compiler/runtime realization is separate targeted evidence.

`negative.nix` preserves the earlier expected-failure controls. GCC 10, a modern
compiler meeting the C++14 prerequisite, later-generation rebuild comparisons,
complete owned tools/base construction and coherent candidate/catalogue validation
remain necessary before proposing any default-base change.
