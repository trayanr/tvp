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
- **Disposition:** the LibYAML conversion edits authoritative `doCheck` rather
  than derived feature metadata. The full Ruby/Bundler customization contract
  evaluates successfully with both original failure cases, and LibYAML's normal
  current batch passes. The original failure stays recorded; this does not claim
  a fresh Ruby/Bundler runtime or full-inventory admission pass.

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
- **Resolved 2026-11-14:** Bison/Flex now use the ordinary family API. The historical
  observer explicitly calls their retained factories with the actual earlier
  packages. All six controls for each, and the complete eleven-family observer,
  pass. The original failure remains recorded; no public fallback adapter or
  assertion removal was introduced.

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

## MIG-014 — Zlib procedures follow actual eras, not exception releases

- **Scope:** the earlier demand for a separate complete 1.2.5.1 procedure.
- **Decision:** use the complete 1.2.3.3-era procedure with the exact source-bound
  version-map parent repair. No builder imports or overrides another builder.
  A source exception does not by itself create a new procedure era.
- **Evidence:** all 65 eligible definitions evaluate; 1.2.5.1 receives an actual
  library build, upstream examples and installed symbol-version/consumer tests.
  Default Make targets are replaced with library targets in production. Example
  compilation and its historical shared-link repair stay in independent U.
- **Disposition:** resolved for this authoring batch. Other historical releases
  remain unqualified here; existing ABI failures and global holds are not waived.

## MIG-015 — Progress reporting must not run unrelated suite assertions

- **Scope:** the status manifest formerly reused full latest-test metadata.
- **Evidence:** forcing that metadata reaches an inherited Expat customization
  assertion before producing a source progress report. Its failure is retained in
  the authoring-status candidate evidence, without an onset claim or waiver.
- **Current behavior:** status validates declared alias selectors through a narrow
  lazy projection. Its measurement is explicitly `declared-selectors`, with runtime
  qualification unknown. The actual latest gate and its suite checks are unchanged.
- **Disposition:** Expat's conversion repairs the authoritative input edits and
  evaluates the original customization contract. Its current package, independent
  CTest execution and all nine normal leaves pass. The original status failure
  stays recorded. Progress metadata still does not substitute for suite acceptance.

## MIG-016 — Standard tool names can collide with recipe options

- **Scope:** implicit family argument defaults when adding a standard base role.
- **Evidence:** adding a camel-case `pkgConfig` provider also filled historical
  Zlib's same-named boolean feature option, making batch evaluation fail. This was
  caught before the six-family build; no package was accepted with that value.
- **Current behavior:** expose the earlier tool as canonical `pkg-config`, consumed
  through `context.tools.pkg-config`; keep Zlib's existing boolean option intact.
  No unrelated production environment receives the tool. Earlier provider and
  compression producer identities are compared explicitly.
- **Follow-up:** after remaining builders use their base context, review removal of
  implicit standard-argument compatibility rather than growing name exceptions.
  This batch does not change the family API or reinterpret existing option types.

## MIG-017 — Libxcrypt ABI baseline requires uncached historical GCC16

- **Scope:** normal Libxcrypt ABI comparison against its exact retained 4.4.36
  default-base producer, outside ordinary family-authoring cleanup.
- **Evidence:** the eight-target dry run reaches the retained baseline through
  only `libxcrypt_4_5_2.tests.abi`, then the historical GCC16-owned stdenv/compiler.
  Current source-built compiler generations remain exact; this is a different
  historical fixture generation, not a required current package compiler rebuild.
- **Current behavior:** preserve the baseline and ABI test unchanged. Do not
  substitute another producer, trim the assertion, fake its output or mark the
  normal Libxcrypt batch passing. Build the current A/F and other leaves while
  retaining this test as NOT_RUN and the normal batch incomplete.
- **Decision needed:** coordinate that historical baseline/compiler realization
  and run the unchanged ABI test; until then ABI qualification remains pending.
- **Assembled follow-up:** the current end-result graph also needs that retained
  GCC generation for captured SDK/JDK seed providers. Realizing this real seed
  dependency once is distinct from launching it only for an authoring count.
  Preserve the providers; keep ABI qualification pending until its actual receipt.


## MIG-018 — Native upstream profiles still reconstruct their build trees

- **Scope:** native SQLite 3.53.4 and OpenSSL 3.6.3/4.0.1 authoring adoption.
  Their package and independent upstream derivations are already separate, but
  those native upstream plans reconstruct private trees from source instead of
  retaining/restoring the compiled tree used by the specialized historical eras.
- **Current behavior:** preserve those production identities, test bodies and
  provider generations. Do not remove upstream checks or claim that an unchanged
  package identity makes the test replay free. The selected OpenSSL 4.0.1 raw
  test actually recompiles its private tree during this validation.
- **Follow-up:** converge those real profiles on the existing checkpoint and
  test factory, coordinating the required production retention change once.
  This authoring pass does not introduce another execution framework or silently
  treat source reconstruction as compiled-checkpoint reuse.


## MIG-019 — Historical Libxml2 headers exceed the strict reader's grammar

- **Scope:** Libxml2 2.9.14's first checkpoint-era representative validation.
- **Evidence:** production A/F, all ten installed leaves and raw upstream exit
  zero pass. Strict acceptance reaches the unchanged source-bound reader, which
  rejects the real configured header directive `#ifdef __cplusplus` with
  `SOURCE_OR_REPORT_BINDING_GAP`. The A/header equality checks pass beforehand.
- **Current behavior:** preserve the reader, raw receipt and failure. The
  historical normal batch remains red/incomplete; neither installed tests nor
  a raw zero exit substitutes for strict acceptance. No XML source fix, corpus
  reduction, known-result waiver or fabricated passing receipt is introduced.
- **Follow-up:** bind header grammars to their actual source eras and qualify
  the reader independently, keeping earlier corpus/conformance gaps distinct.


## MIG-020 — Effective provider roles and scoped authoring observers

- **Scope:** public runtime authoring, implicit base tools and family instantiation.
- **Repairs:** OpenSSL header-version assertions follow the compile-time provider,
  while linkage assertions retain the runtime provider. Python's final-inspector
  probe uses suffix-only step edits; changing construction Binutils legitimately
  changes A. Replace Python's obsolete global debt-count equality with actual
  family split admission. Expose the existing earlier Gzip in the raw base fallback.
  Omitted `.instantiate` bases honor `versionTable.<version>.def.base`; explicit
  caller bases remain authoritative.
- **Evidence:** all runtime/compiler source contracts and 55 family-model controls
  pass; four PHP/Python normal batches pass 76 leaves. Protected compiler and
  construction snapshots remain exact. Original failed observations are retained.
- **Disposition:** resolved at these scopes; no production API or test waiver is
  introduced to preserve an obsolete observer expectation.

## MIG-021 — Python production targets include upstream build scaffolding

- **Scope:** general-purpose and reduced Python production profiles.
- **Current behavior:** preserve actual `build_all`, install targets and installed
  features. They include test embedding scaffolding and extension-import checking
  in newer releases. Full suites remain separate F consumers; profile-specific
  disabled modules and TLS behavior remain explicit. Production identities match
  all thirteen pre-authoring profiles.
- **Follow-up:** decide which generated scaffolding is a required production
  dependency, and move genuinely test-only work using the existing checkpoint
  boundary. Do not silently disable extensions or claim all production is test-free.

## MIG-022 — Compiler generations and deferred assembled execution

- **Scope:** public compiler family authoring and Ruby's actual Rust dependency.
- **Current behavior:** ordinary compiler host bases use the closed earlier full
  tier; target GCC runtimes remain explicit dependencies. Direct bootstrap,
  construction and frozen generations retain their exact procedures/providers.
  Temporary `build-owned-*` root names distinguish ordinary procedures while old
  direct root callers remain; their removal needs actual caller migration.
- **Evidence:** public GCC13/GCC16 and Rust A/F stay exact. LLVM/Go selected-shell
  floors become coherent with their effective bases, changing their production
  identities. Ruby/Bundler's dry run reaches uncached public GCC16 through Rust,
  even though the closed earlier full compiler is valid.
- **Decision:** finish the remaining dependency authoring before realizing this
  public compiler generation. Do not replace its runtime provider with a cached
  generation, disable Ruby YJIT, or mistake identity equality for store availability.
  Deferred current/compiler tests remain pending, not accepted or waived.


## MIG-023 — Provider projections must include implicit active tool roles

- **Scope:** effective runtime ownership after standard tools moved to bases.
- **Evidence:** historical Perl's runtime `pwd` could change F while the accepted
  Coreutils provider projection was ignored because Coreutils was no longer a
  formal recipe argument. A pure regression failed on the old implementation.
- **Repair:** apply projections to collected active tool roles before merging
  explicit dependencies. Unknown names remain errors; unused values stay lazy,
  multi-provider keys and explicit-dependency precedence remain intact. Eighteen
  model controls and actual Perl source-level A/F/provider probes pass, with a
  separate independent source review. No per-package runtime-provider workaround.
- **Disposition:** resolved at source/metadata scope. This does not claim fresh
  runtime execution of historical Perl.

## MIG-024 — Concrete multi-directory checkpoint layouts

- **Scope:** JSON-C's separate source/build directories, Zstd's sibling source
  directory and Binutils's separate build tree.
- **Decision:** reuse the existing checkpoint/restore behavior through a bounded
  explicit multi-directory adapter. Record actual original paths and timestamps;
  validate destinations and complete timestamp coverage before restoration.
  Existing single-tree helpers remain byte-identical. No new runner, classifier
  or generic arbitrary-host protocol is introduced.
- **Evidence:** host-only two-directory roundtrip and destination/parent rejection
  controls pass. Real upstream restoration remains part of end-result validation;
  additional host layouts and arbitrary path schemes are not certified.

## MIG-025 — Retained construction callers and test-factory compatibility

- **Scope:** root procedure names, old indexes and test factories still imported
  directly by earlier compiler/bootstrap generations or real public profiles.
- **Decision:** preserve actual earlier producers at their original paths. New
  ordinary root files may temporarily carry `owned`, `native` or `current` names
  where the old versioned path is still a live input. Ordinary tables use one
  implicit constructor; retained modules are not another ordinary fallback.
- **Test boundary:** retain existing named `pkgs`, locale, helpers and counterpart
  overrides in narrow test-only adapters where a caller exists. The main owned
  factory stays `{ package, lib, context }`; old test backends and graph-export
  audits do not enter production. A future caller migration can remove these
  adapters only after evaluating its real generation identities.
- **Measured limit:** Readline 2.0 and SQLite 3.2.8 retain their declared broken
  records and procedures, but their derived producer IDs follow changed live
  public dependencies. They are not frozen-output proofs. Captured closed/full,
  bootstrap, construction compiler and frozen-tool snapshots remain exact; this
  does not certify every unmeasured historical caller or runtime closure.

## MIG-026 — Remaining production/upstream isolation and historical execution

- **Scope:** the authoring pass preserves actual production features and known
  test profiles; source adoption alone does not complete every isolation task.
- **Known debt:** native SQLite/OpenSSL reconstruct private upstream trees
  (MIG-018); several existing Bash/SDK/font/utility/Perl upstream consumers likewise
  reconstruct source rather than restore a compiled tree. Source Dart still runs
  its existing selected upstream checks before its artifact split. Python retains
  required/default build scaffolding (MIG-021); Fontconfig's public profile keeps
  its tests-enabled construction payload. Zstd 1.5.6's existing combined source
  helper prepares CLI frontends before A, unlike the corrected 1.5.7 U boundary.
  The distinct retained GCC16 seed required by captured SDK/JDK providers still
  runs DejaGNU in its construction `checkPhase`. The current ordinary GCC uses
  separate upstream consumers; that does not isolate the preserved seed recipe.
- **Decision:** keep these visible, without disabling features, inventing coverage
  or launching historical compilers merely to claim an authoring pass is green.
  Converge on the existing A/F/U capabilities in a separately reviewed change.
  Strict historical nonpasses, Libxcrypt's exact ABI baseline, XML conformance and
  full/hardening/admission limits remain unwaived.
- **Review correction:** the initial text-tool report inferred all Binutils
  readers were missing. Active helpers also register tagged tool providers, so
  that blanket P1 claim was withdrawn. Direct effective-base readers remain a
  valid cleanup; the original evidence and correction are both preserved.
