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
- **Current behavior:** ordinary GMP/MPC/ISL use shared family procedures. The
  standalone source-consumer and native/full compiler library inputs activate
  those root procedures together; the duplicate direct `build-steps` and owned ISL
  procedures are removed. Historical catalogue library selections remain exact.
  The reduced/full compiler generations change once for this coordinated batch;
  earlier seed/target compiler and libc providers remain exact.
- **Remaining work:** standalone activation is grouped; the historical catalogue
  base conversion remains separate. Its GCC13 `rebuild` still requires legacy
  stdenv/overrideAttrs calls for six library placements. Convert those actual base
  stages before removing their retained library procedures. Frozen observer
  decisions remain MIG-007/MIG-009; do not silently rebaseline them.

## MIG-006 — Foundational build-tool ordering (prerequisite resolved)

- **Scope:** build-only roles preceding GMP/MPFR; historical construction callers
  remain separate from the ordinary M4 family.
- **Evidence:** selecting public M4 for GMP exposed more than the Gawk5 → MPFR
  edge: public Diffutils, Findutils, Patchelf and build Python reach Coreutils →
  GMP; public Tar's compressor bindings and M4's Gzip do the same. Original
  evaluation traces are retained in the local `m4-gmp-family-authoring` logs.
- **Current behavior:** `bases/source-gnu/standard-tools.nix` explicitly selects
  the preceding native generation's named build roles. M4 selects those base
  roles and the existing earlier Gzip provider. Package-specific library choices
  remain public TVP selectors. All nine ordinary GMP versions evaluate without
  cycles; no fallback or package-name-based rescue is introduced.
- **Remaining work:** ordinary M4 now uses the family API; its retained construction
  recipe still serves historical stdenv callers. Keep those selectors and the
  bootstrap-pinned Make helper bytes exact until their real callers move. Do not
  promote build-only roles to final public aliases without checking the resulting
  construction graph.

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

## MIG-008 — Standalone family instantiation capability

- **Scope:** the source bootstrap without the catalogue or nixpkgs package set.
- **Evidence:** its explicit pure library lacks the overridable/version-table API
  used by `mkFamily`. Importing public TVP would force the full base being built.
- **Current behavior:** standalone GMP, MPFR, MPC and ISL directly instantiate the
  same complete root procedures, with explicit earlier owned bases/dependencies
  and shared test factories. No duplicate implementation or public fallback.
- **Decision needed:** expose the minimum pure family facade to standalone stages
  or retain direct shared-procedure calls there. Do not import the final catalogue
  to satisfy this interface.

## MIG-009 — Frozen locale helpers still follow public tools

- **Scope:** preserving the complete historical locale fixture graph.
- **Evidence:** before/after producer comparison preserves the six selected
  historical GMP/MPC/ISL variants and frozen Coreutils, but not the locale fixture.
  Python-minimal's retained definition selects public Bash; Bison and Linux
  headers select public Perl. Those helpers follow the changed standalone compiler.
  Frozen MPC 1.4.1 and ISL 0.28 themselves remain exact too.
- **Current behavior:** retain original locale identities/evidence and record the
  changed identities as unresolved drift. No acceptance/rebaseline is claimed and
  no historical locale build is requested by this activation.
- **Decision needed:** bind explicit earlier helper generations when converting
  the historical base/observer graph. Retaining a recipe file alone cannot freeze
  its transitive public selections.

## MIG-010 — Whole-inventory validation crosses unrelated test scopes

- **Scope:** the broader dependency inventory and untouched Ruby/LibYAML checks.
- **Evidence:** forcing all support rows for MPC also evaluates Ruby/Bundler's
  LibYAML check-boundary assertions, which report `editedCheckDisabled=false` and
  `editedCheckReenabled=false`. Those family implementations are unchanged here.
- **Current behavior:** the inventory exposes its existing explicit support rows
  by consumer as well as the complete flattened report. MPC validates its actual
  registered providers through that scoped view. A throwing unrelated-provider
  probe verifies laziness; the broader failure is preserved, not waived.
- **Decision needed:** repair the live LibYAML test-boundary assertions in that
  family's conversion. Keep full-inventory admission distinct from scoped package
  checks instead of silently skipping the unrelated nonpass.

## MIG-011 — Deferred heavy providers behind a historical frontend

- **Scope:** pkg-config 0.27's real Gettext dependency, beyond ordinary table and
  frontend-builder cleanup.
- **Evidence:** the local dry run retains `gettext = tvp.packages.gettext`, which
  reaches uncached public GCC16 and JDK21 through the current Gettext feature set.
  Removing that dependency or silently changing its profile would change the recipe.
- **Current behavior:** all six pkg-config rows are source-converted; 0.27 remains
  explicitly uncompiled/unqualified. The other five and all three Ninja releases
  have bounded normal-batch qualification. No compiler/JDK build is launched merely
  to clear this source cleanup, and there is no lighter-provider substitution.
- **Decision needed:** coordinate the public compiler/toolchain and Gettext feature
  activation, then qualify the exact ordinary 0.27 recipe. Historical construction
  and its measured Gettext/JDK override remain separate and retained.

## MIG-012 — Flex's historical public test-factory fallback

- **Scope:** the retained factory observer outside the Autotools family conversion.
- **Evidence:** `lib/tests/legacy-test-factories.nix` reports
  `flex.defaultIdentities=false`; selected-builder, retained-control and variant/base
  checks remain true. The converted Autoconf/Automake/Libtool retained factories
  pass all six controls each. Flex's public factory still overrides its historical
  default with a different `pkgs` context. Exact onset has not been established.
- **Current behavior:** preserve the full observer's failure and captured diagnostic.
  Scoped Autotools source checks use the three actual retained factories; the full
  check stays red. No public fallback adapter or silent assertion removal is added.
- **Decision needed:** when Flex moves to the agreed family API, separate its owned
  factory from this historical observer and preserve the actual selected earlier
  base. Repair/retire the old fallback explicitly, with its own identity evidence.

## MIG-013 — GNU Config remains a live historical Ncurses provider

- **Scope:** construction/frozen observer adoption after ordinary GNU Config moves.
- **Evidence:** `bases/gcc13-owned/inputs/test-public.nix` captures Autoconf,
  Automake and Libtool, but not GNU Config. Old Ncurses still selects the ordinary
  GNU Config alias.
- **Current behavior:** preserve GNU Config's installed layout and revision/shell
  interface; keep its old recipe explicit. Do not retroactively add it to a captured
  historical package set and call that preservation. Historical Ncurses consumers
  of the new provider are not newly qualified here.
- **Decision needed:** choose explicit historical provider generations when those
  construction callers move, retaining their prior identities and observations.
