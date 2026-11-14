# Deferred migration decisions

These open items were found while implementing the agreed package model. They do
not authorize new exceptions or certify untested behavior. Resolve them explicitly
when their scope is reached; retain the current boundaries meanwhile. CI and NAS
remain off under the [migration execution policy](AUTHORING-MIGRATION.md).

## MIG-001 — Historical origin/runtime audit protocols

- **Scope:** adapting or retiring historical construction observers after the
  compiler split, beyond the bounded production/test separation.
- **Evidence:** [`source-full-gcc-origin-audit.py`](../bootstrap/source-full-gcc-origin-audit.py)
  fixes prior graph counts and recognizes an older stage/text-copy protocol.
  [`source-full-gcc-runtime-audit.py`](../bootstrap/source-full-gcc-runtime-audit.py)
  also requires prior Graphviz observations and their permission sets.
- **Current behavior:** retain these observers and their historical records. They
  do not qualify the new compiler/driver graph; scoped current checks are separate.
- **Decision needed:** keep them as historical readers or port them to the current
  producer/provenance interface with independently checked permissions. Do not
  change expected counts merely to make an audit pass.

## MIG-002 — Public GCC production Python selection

- **Scope:** later whole-family GCC cleanup, including both public GCC13 and GCC16
  callers.
- **Evidence:** [`pkgs/compilers/gcc/default.nix`](../pkgs/compilers/gcc/default.nix)
  still selects the Python validation profile as `python`. That
  [profile](../bootstrap/source-gcc-python-tests.nix) includes pytest,
  check-jsonschema and their runtime modules. A separate `testPython` input in
  the shared GCC16 procedure allows the private construction call to avoid this.
- **Current behavior:** private GCC16 supplies raw production Python and the
  validation profile separately. Existing public provider bindings remain for
  their later family conversion; no claim of complete public test-tool isolation.
- **Decision needed:** establish production Python requirements and select its
  earlier provider consistently when converting the public family and test factory.

## MIG-003 — Configure-visible File/libmagic

- **Scope:** a source-bound provider-role audit; removing a tool from production
  can change configured behavior even if explicit build commands do not invoke it.
- **Evidence:** [`source-full-gcc.nix`](../bootstrap/source-full-gcc.nix) retains
  `file` in the shared compiler's production tool list. The native linkage test
  uses the same File/libmagic generation, and independent libbacktrace validation
  also supplies it.
- **Current behavior:** conservatively keep the exact File provider visible to
  configure. Its exclusively test-only role has not been established.
- **Decision needed:** inspect the actual configure/generated-tool bindings and
  decide whether File can move entirely into test preparation without changing
  production capabilities or silently disabling coverage.

## MIG-004 — Configured GCC checkpoint restore roots

- **Scope:** general restoration under a different build-root layout or host.
- **Evidence:** [`restore-16.2.0.py`](../pkgs/compilers/gcc/tests/restore-16.2.0.py)
  prefers the original private workspace. Its fallback rebases a limited set of
  generated text files; compiled products can contain other absolute build paths.
- **Current behavior:** reuse the existing checkpoint/restore mechanism for the
  bounded native pilot. A general relocation guarantee and cross-host reuse are
  unproved; a restore failure remains visible.
- **Decision needed:** either require an explicitly supported original-root
  restoration contract or prove a broader relocation policy with real compiler
  evidence. Do not hide the limitation through sandbox exceptions or binary edits.

## MIG-005 — Construction-input activation and frozen baselines

- **Scope:** the next GMP/MPC/ISL construction batch, beyond this compiler split.
- **Evidence:** `bootstrap/source-consumers.nix` supplies GMP to the reduced native
  compiler; replacing that producer changes both the reduced and full compiler.
  `bases/gcc13-owned/inputs/test-tools.nix` and `test-locale.nix` separately retain
  explicitly frozen GMP test baselines.
- **Current behavior:** the ordinary GMP family now uses the agreed family API.
  Its historical construction recipe is isolated in `gmp/retained/`, and the two
  direct `build-steps-6.3.0.nix` callers remain unchanged. Before/after evaluation
  confirms both compiler generations, their drivers and GCC13/GCC16 GMP inputs
  remain exact. Do not activate a new compiler input after every family rewrite.
- **Decision needed:** group construction-input activation and qualification into
  a deliberate batch. Decide explicitly whether frozen test procedures remain
  historical fixtures or are rebaselined; do not silently delete or replace them.

## MIG-006 — Foundational build-tool ordering (prerequisite resolved)

- **Scope:** build-only roles preceding GMP/MPFR; full M4 authoring conversion
  remains later work.
- **Evidence:** selecting public M4 for GMP exposed more than the Gawk5 → MPFR
  edge: public Diffutils, Findutils, Patchelf and build Python reach Coreutils →
  GMP; public Tar's compressor bindings and M4's Gzip do the same. Original
  evaluation traces are retained in the local `m4-gmp-family-authoring` logs.
- **Current behavior:** `bases/source-gnu/standard-tools.nix` explicitly selects
  the preceding native generation's named build roles. M4 selects those base
  roles and the existing earlier Gzip provider. Package-specific library choices
  remain public TVP selectors. All nine ordinary GMP versions evaluate without
  cycles; no fallback or package-name-based rescue is introduced.
- **Remaining work:** migrate the complete M4 authoring index and its construction
  callers in their scope. Do not promote build-only roles to final public aliases
  without checking the resulting construction graph.

## MIG-007 — Frozen library test and observer interfaces

- **Scope:** MPC/ISL conversion and coordinated construction activation.
- **Evidence:** GCC13/GCC16 and `test-locale.nix` retain coverage-parser providers
  and codec graphs; their historical test factories still expect the old tooling
  and step names. The GMP frozen test factory likewise remains explicitly retained.
- **Current behavior:** preserve these bindings and their evidence. Ordinary GMP
  uses one installed suite and independent upstream acceptance; frozen construction
  retains its own historical factory. A source cleanup does not certify unbuilt
  releases or waive any old upstream failure.
- **Decision needed:** distinguish frozen historical observers from live acceptance
  when their callers move. Port live checks to effective base/dependency interfaces;
  do not silently rebaseline historical fixtures or keep obsolete production steps
  solely to satisfy old observer assumptions.
