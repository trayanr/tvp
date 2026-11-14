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
