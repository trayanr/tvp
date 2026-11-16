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
  LLVM's upstream consumer configures a separate source tree with
  `LLVM_INCLUDE_TESTS=ON` and recompiles production objects. Its independent test
  derivation does not yet reuse a compiled checkpoint. Keep that performance debt
  separate from ordinary index adoption and A/F split compliance.
- **Decision:** keep these visible, without disabling features, inventing coverage
  or launching historical compilers merely to claim an authoring pass is green.
  Converge on the existing A/F/U capabilities in a separately reviewed change.
  Strict historical nonpasses, Libxcrypt's exact ABI baseline, XML conformance and
  full/hardening/admission limits remain unwaived.
- **Review correction:** the initial text-tool report inferred all Binutils
  readers were missing. Active helpers also register tagged tool providers, so
  that blanket P1 claim was withdrawn. Direct effective-base readers remain a
  valid cleanup; the original evidence and correction are both preserved.

## MIG-027 — Compiler-family base selection and coherent provider edits

- **Public selection:** bases are grouped by compiler line, with no composition
  revision counter. GCC16 exposes the real `seed`, `runtime`, `reduced` and `full`
  contexts. GCC13 exposes its retained complete owned adapter as `full`; the old
  v2/v3 wrapper protocols do not establish reduced/full compiler stages. Existing
  base names remain unchanged because they are recorded by actual consumers.
- **Platform:** the root resolves the selected system through `bases/platforms`.
  Ordinary definitions inherit that platform. Native x86_64 GNU/Linux remains the
  only implemented platform; a new registry entry alone does not qualify a port.
- **Provider authority:** `tools.gcc` selects a whole compiler driver. Compiler,
  shell, Coreutils, Binutils and libc aliases derive from the effective catalogue.
  The existing driver constructors expose different real override interfaces;
  generic independent Binutils/libc changes are rejected when they disagree with
  the selected driver. Adding advertised provider-specific rebinding is later work.
- **Laziness:** named tools are validated when selected. The catalogue is never
  converted wholesale to execution inputs. Existing explicit baseline tools stay
  in `baselineTools`, including the GNU linker contribution used by hardening
  consumers. Inferring replacements from matching output paths would lose that
  contribution and change production identities.
- **Compatibility:** old constructor lists and `standardTools` overrides are
  translated at the owned-base boundary. `standardTools` is a derived view, not
  another stored choice. Existing stdenv callers and flat graph labels use the
  private `__legacyBases` surface, pinned before the public default advances to
  `gcc16.full`. Removing those adapters requires actual caller migration (MIG-025);
  new ordinary definitions must not use them.
- **Edit semantics:** no-op edits preserve explicitly selected provider metadata
  and enriched baseline contributions. Complete edits can remove optional fields;
  missing required fields fail clearly. Driver edits derive inherited Binutils
  bindings again; contradictory explicit choices remain errors.
- **Status:** evaluated contexts include system, target, compiler version, driver,
  Binutils/libc and only used tool roles. Nix JSON provider records use `path`:
  an `outPath` field would cause Nix to serialize the whole record as a string.
  Compiler-wrapper versions are reported separately from the underlying GCC version.
- **Preserved limits:** the pre-existing construction snapshot check fails on the
  original commit as well as the refactor. Its historical JSON baseline is not
  refreshed or waived. All 1,794 current graph entries are independently identical
  across the change. The broad dependency-policy traversal also reaches an old
  JDK test assertion expecting the retired builder filename; that unrelated
  contract cleanup remains outside this change. Selected base contracts now
  recognize the already-owned MPFR construction instances and their exact earlier
  helper context, instead of assuming every retained instance exposes stdenv.
  Historical qualification, checkpoint debt and full/admission holds remain open.

## MIG-028 — Subsystem entrypoints own composition

- **Ownership:** `bases/default.nix` composes public compiler families, resolves
  the selected platform and chooses the default. The retained construction
  assembly lives in `bases/retained.nix` and is passed explicitly as private
  wiring. GCC16's full-stage tool defaults select its local earlier stage;
  construction no longer reaches through the global public base catalogue.
- **Other entrypoints:** `pkgs/default.nix` owns selector tagging, aliases and
  public variant projection. `tools/default.nix` owns CLI/provider assembly;
  `checks/default.nix` composes repository checks and existing audits;
  `tests/default.nix` owns lazy batch/latest registration, with audit fixtures in
  `tests/support.nix`. `reports/default.nix` owns evaluated inventories, graph and
  ownership/status composition. Root only wires inputs, shared context, modules
  and public exports.
- **Private handles:** related module results can carry explicit assembly handles
  such as `ownedCLI`, `runtimeRegistry`, `allVariantPackages` and
  `testBatchEntries`. Root does not add these to the public TVP record. The existing
  `__legacyBases` compatibility field remains private-by-convention and unchanged.
  These are plain imports and lazy records, without a new module framework.
- **Preservation:** public exports, check registration, all 2,062 package selectors,
  all six CLI derivations, 1,794 graph entries and captured stage/provider and
  artifact/final identities remain unchanged at the same input source binding.
  The formatting check intentionally retains the repository root; its source
  snapshot changes when files move. Flake-bound status metadata likewise records
  the new source tree. Neither is a compiler or package-definition change.
- **Limits:** MIG-025–027 and the existing construction/JDK audit nonpasses remain
  unchanged. No new architecture, provider upgrade, historical qualification,
  CI execution or NAS operation is included in this organizational pass.

## MIG-029 — Real GCC13 contexts and historical GCC9/GCC4.9 callers

- **GCC13 composition:** the family now owns `seed`, `libc`, `shell`,
  `compilerPreparation`, `compiler`, `toolFloor` and `full`. These correspond to
  the actual retained construction boundaries. There is no separately reduced
  GCC13 compiler, so the GCC16 stage names are not copied onto unrelated stages.
  This extends the stage availability recorded in MIG-027.
- **Live callers:** local contexts are created from raw earlier stage inputs
  before their consumers. Both retained-chain owned MPFR instantiations now use
  the shell/compiler contexts directly. They do not fetch their base through the
  completed public GCC13 object, which would risk a compiler/prerequisite cycle.
- **Provider protocol:** the existing GCC wrappers explicitly declare the same
  runtime directories and libc tools formerly inferred by the compatibility
  adapter. Executable scripts and hardening choices are unchanged. Full retains
  the rich native platform, ordered baseline and reference ownership. Python and
  Patchelf retain their captured earlier provider generations.
- **Bounded completion:** this is owned stage-context and caller migration. The
  borrowed seed, most retained producer recipes, wrapper production, setup hooks
  and libc tool construction remain on their existing implementation. Full producer
  conversion requires preserving their actual features and build/checkpoint
  contracts and will change derivation identities; it is separate work. Do not
  label the retained GCC13 source-bootstrap migration complete from these contexts.
- **Historical compiler audit:** GCC9 9.5.0 is selected by broken Readline 2.0.
  GCC4.9 4.9.4 is selected by ten broken Zlib releases: 0.71, 0.79, 0.8, 0.9,
  0.91–0.95 and 0.99. No supported canonical recipe, public variant or retained
  construction variant selects either. Each still has eight base tests and a
  registered full/all batch, plus live graph and historical baseline records.
  Deletion would require an explicit disposition for those callers, suites and
  records, so both remain private historical compatibility contexts.
- **Comment correction:** the recorded Zlib blocker already requires GCC <= 3.3;
  GCC4.9 also rejects its cast-as-lvalue syntax. Correct the stale nearby comment
  without changing the broken records, their compiler selections or their status.
- **Validation:** raw stage bindings, internal MPFR A/F, full tools/platform and
  ordered references, captured production identities and all 1,794 graph entries
  remain exact. Seven concrete C compile/link/run probes pass; full also passes
  C++. No compiler producer is rebuilt. Existing upstream, historical, checkpoint,
  construction snapshot and admission limits remain unwaived.

## MIG-030 — Authoritative owned GCC13/GCC9/GCC4.9 base definitions

**Superseded provider decision:** MIG-033 removes the borrowed providers below.
This interface conversion did not complete the requested source migration.

- **Definition boundary:** remove `mkBase` and convert all seven declarations,
  including the retained GCC16 consumer environment, to an actual owned
  definition followed by `legacyEnvironment`. The checked projection derives old
  version strings/floor names and retains stdenv only for pinned producer callers.
  It must compare compiler, Binutils, libc, ordered baseline, Bash and platform;
  it cannot introduce an independent selection policy.
- **Public families:** GCC13 retains its seven real contexts and selects its locally
  composed v3 full driver. GCC9/GCC4.9 publish only `full`; no fictitious native
  intermediate stages or source-bootstrap claims are added. This supersedes
  MIG-029's private-only visibility for the two historical contexts.
- **External seed:** `borrowed-tools.nix` names exact providers instead of discovering
  roles by package-name strings. Make and File deliberately come from the pinned
  Nixpkgs producer generation rather than later public rebuilds. `borrowed.nix`
  adds the owned compiler metadata protocol without rebuilding the external driver.
  Retained environment projections verify the ordered selection still matches.
- **Historical callers:** broken Readline 2.0 and ten Zlib 0.x public entries now use
  genuine owned split procedures and the new family contexts. Reuse historical
  installed test bodies; do not apply the modern shared-library suite to libgz.a.
  Keep source hashes, statuses, reasons, compiler requirements and original defects.
  In particular, do not repair the missing Readline header or Zlib cast-as-lvalue
  source as part of a base-interface change. Their eleven obsolete split exceptions
  are removed only after evaluated producer/partition checks pass. Nine exceptions
  remain; all twenty declared-broken statuses remain unchanged.
- **Validation construction:** the eight common base tests use the existing owned
  test factory and the effective selected providers. They accept an owned base or
  a retained projection; extra suites/ownership callbacks remain compatible.
  Compiler/runtime producer bodies and setup hooks have not thereby migrated.
- **Screening scope:** `tools/definition-inventory.py` reports lexical API use and
  static source references without Nix evaluation or builds. Its output is an
  inventory, not an admission policy or runtime-liveness proof. The 110 ordinary
  entrypoints use `mkFamily`; 130 retained package files still use `mkDefs`, 87
  declare `packageArgs`, and 152 package producer files use `mkDerivation`.
  Keep the nine test-factory bridges and restricted `standardTools` selections
  explicit until their actual callers move. Do not delete retained sources based
  solely on directory names or an unreferenced-file heuristic.
- **Result/limits:** 188 pure controls, scoped base/platform/catalogue checks and
  all 24 GCC13/GCC9/GCC4.9 shared execution leaves pass. Compilers/providers are
  reused; captured supported canonical/variant A/F and retained context providers
  stay exact. Exactly eleven broken public producer graph entries change.
  Latest/public-profile outputs are reused with builds/substituters disabled.
  Source archive preflight and runtime qualification of the new broken procedures
  remain unrun; required Readline2.0/Zlib0.x archives are absent locally. Existing
  historical construction snapshot, JDK caller-audit and wider qualification
  nonpasses remain unwaived. CI/NAS stay off.

## MIG-031 — Canonical compiler versions and latest-major base aliases

- **Public names:** base selectors use the same dot-to-underscore spelling as
  package selectors. Exact registrations are `gcc_4_9_4`, `gcc_9_5_0`,
  `gcc_13_3_0` and `gcc_16_2_0`.
- **Aliases:** `gcc_4`, `gcc_9`, `gcc_13` and `gcc_16` select the greatest registered
  version of that compiler major. In particular, `gcc_4` currently selects 4.9.4;
  it is not a minor-line alias. Only major aliases are emitted; `gcc_4_9` is not
  provided. Ordinary callers use major aliases; construction can pin exact selectors.
  `default` continues to select `gcc_16.full` explicitly.
- **Selection:** compare table version strings with `builtins.compareVersions`.
  Never compare attribute names or infer `49` as GCC4.9. Selection does not evaluate
  compiler providers or unused stages. Package alias tagging is not applied to base
  records; aliases return the original selected family without a wrapper.
- **Internal naming:** versioned names apply to owned and retained contexts as
  well as public selectors. Callers, graph/status labels and fixture keys should
  follow naming changes together. Existing identifiers are not a compatibility
  requirement; runtime providers and execution behavior are validated separately.
- **Validation:** ten pure alias cases cover major grouping, minor/patch ordering,
  empty input and lazy unselected stages/providers. Actual-family contracts bind
  every major alias to its exact compiler/stage set. Captured package A/F, variants,
  compiler contexts and all 1,794 production graph entries remain identical.
  Scope is selector naming; no package or compiler rebuild, architecture work,
  source qualification, CI or NAS execution is introduced.

## MIG-032 — Versioned base filenames and consistent internal names

- **Files:** use `bases/gcc-4.9.4.nix`, `gcc-9.5.0.nix`, `gcc-13.3.0.nix`
  and `gcc-16.2.0.nix`. GCC13's stage/full helpers live under `gcc-13.3.0/`.
  Imports, current guides and links follow the new paths.
- **Identifiers:** owned and retained GCC4/GCC9 context names use `gcc_4_9_4`
  and `gcc_9_5_0`. Update private callers, graph/status keys and construction
  fixture keys together. Keeping old identifiers for historical compatibility
  is not a requirement; no compatibility alias is added for the old spelling.
  Upstream Nixpkgs attribute names remain its external API.
- **Public selection:** callers continue to use `gcc_4`, `gcc_9`, `gcc_13` and
  `gcc_16`, with exact canonical version selectors available. Alias selection,
  actual compiler providers and the default are unchanged.
- **Verification:** source references and registered selection checks validate
  the new paths/names. Captured package A/F, variants, compiler contexts and all
  common graph entries remain exact. The only graph key changes are the two
  explicitly renamed retained base records; their provider paths stay the same.
  Naming cleanup is not a runtime qualification or an upstream failure waiver.

## MIG-033 — Actual source-owned base providers

- **Correction:** an owned base record around a Nixpkgs compiler/tool floor is
  incomplete migration. Remove `borrowed.nix`, `borrowed-tools.nix` and the old
  GCC13/v2/v3/GCC16 construction graph. Do not preserve their identities or invent
  produced stages to retain an obsolete shape.
- **Registry:** `bases/default.nix` accepts system, pure library and builder only.
  GCC4.9/GCC9/GCC13 expose their actually produced `full` stage. GCC16 retains its
  four real source-bootstrap stages. Major aliases still select exact versions.
  The catalogue also evaluates with the standalone owned library, without importing
  Nixpkgs. Repository-level pure `lib`/`config` use is separate from executable
  provider selection.
- **Construction:** build GCC4.9.4, GCC9.5.0 and GCC13.3.0 on the existing closed
  source-GNU16 predecessor. Earlier means earlier in the construction DAG, not a
  smaller compiler version. Explicit source prerequisites avoid public-alias cycles.
  GCC4/GCC9 have complete independent procedures, genuine A/F boundaries and
  explicit capability exclusions; their missing optional profiles are not claimed.
- **Compatibility:** remaining stdenv recipe syntax uses the local vendored
  constructor with the selected source compiler, libc, Binutils, File and tool
  floor. Its metadata comes from those actual providers. It cannot select a foreign
  stdenv, fabricate a libc tools output, or reconstruct the removed variant graph.
  Removing this remaining recipe syntax is separate authoring work.
- **Compiler layout:** use libc headers after compiler headers (`-idirafter`) and
  select the libc sysroot with the native `/include` header root. GCC13's first two
  source attempts exposed incorrect retained header/sysroot assumptions. Preserve
  their diagnostics; correct the production recipe rather than its cached tree.
- **Reusable finalization:** GCC13's successful bootstrap/comparison/install/checkpoint
  produces a valid A. Its finalization-only ELF correction reuses that exact A.
  `finalize-standard.py` handles ordinary GCC's configured-prefix diagnostic bytes
  separately from dynamic strings, while retaining full artifact-reference checks
  and exclusive RPATH validation. The closed patched GCC16 layout keeps its existing
  finalizer, avoiding an unrelated bootstrap rebuild.
- **Enforcement:** `checks.source-base-providers` checks the actual source floor,
  driver, raw compiler lowering, A/F boundary, predecessor, sysroot and runtime
  providers. Its source guard covers sixteen active modules. The current evaluated
  production traversal checks 45 providers; seven mutation controls exercise
  rejection/acceptance boundaries. These are bounded provenance checks, not an
  unrestricted store-closure or compiler-conformance certificate.
- **Validation:** 198 pure controls, nine source-GCC13 composition contracts,
  seventeen MPFR assertions, registered base/platform/catalogue checks and normal
  Git-backed origin evaluation pass. GCC13 A/F/driver build and bootstrap comparison
  pass; fresh source-GCC13 and source-GCC16 legacy C/GMP/C++ probes pass. Both common
  base suites pass seven of eight leaves: bind-now hardening remains a real failure.
  Do not weaken that assertion or reuse old borrowed-provider qualification.
- **Limits:** GCC4/GCC9 real source preparation/configuration pass, but their
  compilers are UNBUILT/UNQUALIFIED. New compiler consumers and full upstream suites
  are not globally requalified. Split coverage remains 1,531 compliant plus nine
  explicit debts; all twenty declared-broken statuses remain. Historical upstream,
  hardening and admission holds remain unwaived. CI/NAS stay off.


## MIG-034 — Uniform package families and construction callers

- **One family definition:** all 110 ordinary indexes own literal releases,
  metadata and test dependencies. Remove imports of prior indexes and exported
  `constructionRecipe`/`constructionBuilder` closures. Construction uses the same
  family's `instantiate` operation with explicit earlier dependencies.
- **Delete obsolete implementations:** remove 136 detached old indexes and their
  559-file closure after source-graph/caller review; remove six additional unused
  caller factories and four code-empty stage READMEs. Keep actual direct
  source-bootstrap procedures and their helpers. Dynamic imports are checked again
  by full catalogue and registered-check evaluation; a source scan alone is not
  enough to establish liveness.
- **Implicit providers:** ordinary tool-floor overlays are removed. Named tools,
  including source-built File, come from the selected base. Go OS/architecture
  and native loader facts are defined once in `bases/platforms` and supplied lazily
  by `mkFamily`. CPython uses canonical `pkg-config`/`grep` roles instead of
  repeated camel-case provider aliases. Genuine earlier compiler, seed, build-host
  and named-profile differences remain explicit.
- **One test factory:** `mkFamily` implements suite/configuration overrides once.
  Extra test options reach `testConfiguration`; matching test dependency names
  replace only declared test inputs. Package-local dispatcher wrappers and old
  runCommand fallbacks are removed. Assertions stay in their family suites.
- **Effective metadata:** grouped tool edits project their effective providers.
  A projection may name a registered base role even when a source-only test removes
  its steps. Only active or explicitly declared providers enter dependency metadata;
  unused values remain lazy and unknown names still reject. Pure controls cover
  inactive/unknown projections and production-preserving test customization.
- **Owned closure audits:** runtime-expectation uses the existing owned test
  context. Optional `exportReferencesGraph` lowering roots only the actual final
  output; expected library paths are context-free. The Nix JSON is copied into the
  private workspace without widening the fresh-step environment. The helper invokes
  the selected audit Python absolutely. No new runner/framework is introduced.
- **No artificial profile differences:** named selectors may share a procedure
  and output when their effective choices match. Do not retain a foreign tool floor
  or duplicate body merely to make a former migration pilot physically distinct.
- **Broken releases:** all twenty status/reason records remain broken. The last
  nine legacy records now have owned A/F plans and no split-baseline exception.
  OpenSSL 0.9.6 has its own complete staged era procedure; unsupported architecture
  is not claimed. Structural compliance does not imply those releases build.
- **Remaining decisions:** preserve multi-URL/archive/retry fetch policies and
  GNU Config's Git source backend until a shared replacement retains availability.
  Source-bootstrap stage authoring, older upstream reconstruction, runtime compiler
  qualification, bind-now hardening and historical/admission holds remain separate.
- **Execution deviation:** an optional test-graph shell fragment initially added a
  blank line to unrelated builder scripts. An unintended request started 152
  derivations, chiefly scripts/runners and source prerequisites, before cancellation.
  No GCC/LLVM compiler producer started. Corrected absent-branch bytes restore every
  recorded compiler/stage identity exactly; the final tiny plan admits only expected
  fixture/test scripts. Keep the cancelled log and inputs visible.
- **Validation boundary:** all canonical/variant descriptions and test registrations
  are evaluated offline, with source/alias/status checks and bounded pure tests.
  Tiny actual closure acceptance and absent-library rejection run on cached tools.
  Changed tool/source selections require fresh consumer qualification later; no
  all-version/full/latest runtime acceptance is inferred. CI/NAS stay off.

## MIG-035 — Share mechanical helpers and preserve explicit policies (2026-11-16)

- Replace34 identical checkpoint readers with `lib/restore-checkpoint.py`;78
  ordinary restore records use `steps.restoreCheckpoint`. Thirteen explicit
  provider/infrastructure records call the same reader directly. Production
  checkpoint saving remains independent of the test reader.
- Share six loader-aware auditors and three prefix relocators. Remove49 redundant
  files including six Nix wrappers. `outputs.checkLoaderPaths` preserves supported
  loader tokens and artifact-prefix rejection; existing `checkPaths` retains its
  absolute-path-only policy. Unresolved LIB/PLATFORM tokens retain their existing
  runtime-existence limitation. New helpers live at lib root; existing helper
  directory inputs remain unchanged. Keep the natural `relocate.py` basename for
  File/Patch's shared implementation.
- Share ordinary command records through `steps.command`, using the effective base,
  environment and explicit working directory.159 equivalent constructors migrate;
  73 specialized flag/logging/compiler/tool-interface constructors remain explicit.
  A pure record helper must not add an automatic phase framework.
- Add `versions.fromArchiveName` for13 mechanically equivalent normalizers. Keep38
  custom regex/tag rules and every include predicate. Remove75 unused `pkgs`
  arguments and three unused version-forwarding exports. Keep literal release
  tables, dependency choices and complete era builders visible.
- Share lazy test fixture construction. Effective package tools, shell and Coreutils
  feed the locale fixture; explicit declared providers and test-factory overrides
  retain priority. Existing GNU locale data remains pinned to glibc2.39; automatic
  selection of other libc locale sources/architectures is separate work. Earlier
  test-base selections remain explicit. Fixtures do not enter production merely
  by appearing in the context.
- Move remaining Nixpkgs-backed suite and aggregate helpers to
  `tests.compatibility`; ordinary contexts remain owned. Correct stale authoring
  diagnostics instead of adding namespace-forwarding aliases for all Nixpkgs lib
  functions. Nixpkgs fetching/tooling/validation dependencies stay allowed.
- Deferred: merging the two identical OpenSSL/SQLite production checkpoint savers
  would invalidate A for481 releases solely to remove two source files. Keep this
  deliberate production-input change for later. Retained specialized constructors,
  custom trackers and provider-specific restore records are listed in the run notes.
- Cache consequence: moving final-output helper inputs changes F identities and
  downstream A identities even where program behavior is unchanged. This run
  records that dependency propagation; it does not compile the changed catalogue
  or infer runtime qualification. Compiler-base providers retain their recorded
  identities. CI/NAS stay off; existing admission and historical holds remain.

### MIG-035 verification follow-up — Flex production recursion

Real compilation exposed Flex2.6.3 test BUILT_SOURCES in production make recursion.
A command-line SUBDIRS override is unsuitable because GNU Make propagates it into
nested directories. Apply a validated atomic change only to the generated top-level
Makefile after configure. Preserve every other directory/rule, reject unexpected
assignments and aliases, and keep Makefile.in unchanged. The upstream workspace
reruns configure, restoring complete tests with the declared Bison provider. This
needs no new version switch, builder flags or duplicate era procedure; all four
supported source layouts satisfy the same guarded operation. Source/installed and
upstream validation passed in the bounded13-version matrix. Other deferred decisions
and historical/global qualification holds remain unchanged.
