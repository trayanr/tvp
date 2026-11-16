# Rolling out the MPFR package model

The accepted package model is documented in [NATIVE-RECIPES.md](NATIVE-RECIPES.md).
All 110 ordinary family indexes and their construction callers use the same
current family definitions. Captured old indexes, duplicate constructor routes
and package-local test-factory adapters are removed. All 1,540 evaluated canonical
and variant rows have owned A/F splits; twenty declared-broken statuses remain.
Runtime qualification and source-bootstrap authoring remain separate work.
MIG-034 records the final caller cleanup and explicit exceptions. MIG-035 records
shared mechanical helpers, lazy test fixtures and the compatibility-test boundary.

[MIGRATION-LOG.md](MIGRATION-LOG.md) records completed steps and bounded validation.
[MIGRATION-DECISIONS.md](MIGRATION-DECISIONS.md) records scope exceptions and design
questions found during implementation. Keep them explicit for later review instead
of adding a package-specific workaround or silently broadening this rollout.

## Migration execution policy

The owner closed the ordinary authoring migration on 2026-11-16 and authorized
landing the final snapshot, running validation and restoring CI/NAS. Operational
restoration is a deployment task; service state is recorded in the closeout receipts.
The temporary policy below describes migration execution, not a continuing exception
for subsequent package changes. Runtime/historical/hardening limits remain explicit.

On 2026-11-14 the owner approved suspending the required `tvp/full` merge check
until this migration is complete. Other branch protections stay unchanged. Keep
CI execution and NAS/cache synchronization off; use scoped Tower-local validation
and cached outputs, with no synthetic passing CI status. Merging the baseline or
later cleanup does not waive qualification limits, hardening holds or historical
failures.

When the owner declares completion, restore strict `tvp/full` protection and
explicitly re-enable CI and NAS operations. The [CI migration workflow](../ci/README.md#temporary-migration-workflow)
records the exception and restoration policy; the normal CI workflow remains
documented for use afterward.

## What is already done

- The owned constructor, artifact/final split, generic helpers and shared test
  factory exist. `context.mkUpstream` executes/accepts independent checkpoint
  tests through the shared factory; assertions remain local.
- `mkFamily` supplies implicit ordinary context, source/test wiring and stage-local
  `.instantiate { version; base; deps; opts; }`.
- Source-owned compiler-family definitions expose GCC4/GCC9/GCC13 `full` and
  GCC16 `seed`, `runtime`, `reduced` and `full`. The public default is GCC16 full.
  Actual compiler build/runtime qualification remains separate from source-plan
  and provider-origin checks. Ordinary build-tool choices live in one lazy named
  `tools` catalogue.
- Subsystem entrypoints own their composition. The repository root connects
  bases, packages, tools, checks, tests and reports through the existing lazy
  context, then exports their public results. Retained construction and audit
  support remain explicit private inputs.
- MPFR has one readable family index and two independent era builders. Base,
  dependency, specification, step and runtime edits remain available.

These are separate measures of progress. Split compliance describes evaluated
production plans. Adoption of the MPFR authoring model describes how families and
their construction callers are written. Runtime qualification describes executed
tests of particular outputs. None implies the other two.

A static source inventory at commit `6d626ef6f31975d0f4a0558f4a861877cfb112cd`
found 110 family entrypoints: 46 libraries, 38 build tools, 13 runtimes, seven SDKs,
five compilers and one data family. Only MPFR used `mkFamily`; the other 109 still
used earlier wiring. This count inspects tracked files matching
`pkgs/<category>/<family>/default.nix`; it is not an evaluation or build result.
The current `status --migration` report measures ordinary index adoption and
split coverage separately. It does not certify builder/caller cleanup or runtime
qualification; those fields remain unknown until separately measured.

From the implementation checkout:

```sh
nix run .#status -- --migration
```

## 1. Finish production/test separation beneath the full base

The retained full-GCC boundary is implemented and locally qualified with its
recorded native and historical limits.
[`bootstrap/source-full-gcc.nix`](../bootstrap/source-full-gcc.nix) now imports
production prerequisites directly and instantiates the same complete
[GCC16 procedure](../pkgs/compilers/gcc/native/build-16.2.0.nix) used publicly.
The duplicate retained compiler procedure has been removed. Production uses raw
construction Python; the validation profile and upstream harness belong to the
independent test factory. Existing harness exports stay lazy for caller compatibility.

Bootstrap comparison remains a production requirement. The artifact retains its
production provenance and configured-tree checkpoint; finalization repairs the
installed output. Upstream execution/acceptance is attached through the existing
test factory and remains a normal validation gate. The driver consumes artifact
provenance at build time, without making it part of its intended runtime interface.
See the [construction reference](../bootstrap/source-full-gcc.md) for boundaries
and historical measurement limits.

Done when a test-tool, test-reader or acceptance-policy edit leaves the compiler's
artifact/final identities unchanged, and failed upstream acceptance leaves those
production outputs usable. Changing this graph can require a deliberate compiler
rebuild; later test-only corrections must reuse it.
Changing the underlying full compiler can also change full-base and downstream
identities. Earlier native/seed provider identities must remain unchanged. The open
audit, provider-role and checkpoint decisions are recorded separately as MIG-001–004.

## 2. Make base composition explicit by role and construction generation

The current public stages are `gcc_4.full`, `gcc_9.full`, `gcc_13.full` and
`gcc_16.{seed,runtime,reduced,full}` under `tvp.bases`. `default` selects GCC16
full. Exact release selectors use package spelling: `gcc_4_9_4`, `gcc_9_5_0`,
`gcc_13_3_0` and `gcc_16_2_0`. A major alias selects the latest registered release
within that major using version comparison; `gcc_4` currently selects 4.9.4.
There is no minor-alias surface or separate composition revision number.

Base migration changes the actual executable providers, not just the record used
to describe them. The borrowed GCC4/GCC9 compilers, borrowed GCC13 seed and old
GCC13/v2/v3 producer assembly have been removed. GCC4, GCC9 and GCC13 now have
complete source compiler procedures on an explicit earlier closed GCC16 context.
They expose only `full`, since they do not have separate owned seed/libc/shell or
reduced-compiler builds. GCC16 retains its real four-stage source-GNU construction.
A newer compiler can construct an older release; version order is not build order.

The GCC4/GCC9 composition lives in [source-compiler.nix](../bases/source-compiler.nix);
GCC13 uses [source-gcc13.nix](../bases/source-gcc13.nix). Raw compiler compilation
and finalization have an actual A/F split. The shared source driver binds the
compiler and its runtimes to the selected source-built libc and Binutils. Explicit
earlier tool/library providers keep these constructions independent of public
package aliases that could depend on the resulting base.

These definitions do not claim that every compiler output is built or qualified.
Source preflight and provider-origin checks are distinct from compilation,
installed controls and upstream qualification. A failed or incomplete compiler
attempt remains unqualified; logs and receipts record its actual disposition.

The root accepts `system`; `bases/default.nix` resolves it through
`bases/platforms/default.nix` once. Ordinary definitions omit platform selection.
Native x86_64 GNU/Linux is the currently supported mode. Other systems, ABIs,
cross compilation and different compiler/libc combinations need actual providers,
recipe support and qualification.

| Responsibility | Current home and boundary |
|---|---|
| Generic base/environment contracts | `lib/owned-base.nix` and `lib/build-environment.nix`; validate supplied providers and compose execution inputs. |
| Supported platform facts | `bases/platforms/`, selected once by the base entrypoint; unsupported systems reject. |
| Family registration and aliases | `bases/default.nix` and `bases/aliases.nix`; explicit exact releases and latest-major selection. |
| Source compiler composition | `bases/source-compiler.nix` for GCC4/GCC9 and `bases/source-gcc13.nix` for GCC13; raw A/F and selected source driver. |
| Source-GNU construction ladder | `bases/tiers/source-gnu.nix` and `bootstrap/`; GCC16's real seed/runtime/reduced/full contexts. |
| Build-tool roles | `bases/source-gnu/standard-tools.nix`; earlier local source-built tools, independent of final package aliases. |
| Old recipe syntax | `bases/compatibility.nix` and `bases/retained.nix`; the local stdenv protocol backed by selected source-owned providers. |
| Provider enforcement | `checks.source-base-providers`; source guard plus evaluated floor, driver, raw A/F, predecessor and runtime-provider checks. |

The repository root wires module results. Package registration and selector
projection belong in `pkgs/default.nix`; CLI assembly in `tools/default.nix`;
repository checks in `checks/default.nix`; batches/latest registration in
`tests/default.nix`; inventories and ownership/status composition in
`reports/default.nix`. These remain ordinary imports using the shared lazy context.

`base.tools` is the authoritative lazy named catalogue. `tools.gcc` selects a whole
driver; `compiler`, `shell` and `coreutils` are derived aliases. Only the execution
baseline and providers used by active helpers/steps become inputs. A tool's presence
in the catalogue does not grant an implicit PATH entry. `standardTools` remains a
temporary compatibility input/view; new edits and definitions use `tools`.

Base edits reconstruct validation, commands and dependencies from the effective
choices. A partial Binutils/libc replacement that disagrees with the driver rejects
clearly. Generic composition cannot rebind executable wrappers through metadata;
select a coherent whole driver or construct one for the intended combination.

Remaining stdenv recipes use `tvp.__legacyBases` as a private syntax bridge.
`bases/compatibility.nix` supplies the repository's vendored constructor with the
selected source-owned compiler, shell, Coreutils, File and tool floor.
`legacyEnvironment` verifies that view and exposes `.ownedBase`. It no longer
wraps a Nixpkgs stdenv or preserves an old Nixpkgs-backed construction graph.
Compatibility records use the exact compiler release keys; old construction
variants are gone. Nixpkgs pure `lib`/`config` values used by assembly are separate
from compiler/executable provider selection.

GCC9 still serves broken Readline 2.0; GCC4.9 serves ten broken Zlib 0.x
entries. Their source/status defects remain separate from the compiler migration;
GCC4.9 does not satisfy the Zlib records' GCC3.3-or-older requirement.

Construction callers now use ordinary family `.instantiate`, supplying explicit
earlier bases and dependencies before public evaluation. Obsolete retained recipe
bodies have been removed; actual source-bootstrap procedures remain explicit.
An old authoring API occurrence is not evidence of
a foreign provider, and a new API occurrence is not proof of source independence.
The provider-origin gate checks actual selections; build/runtime tests validate
execution. Recipe syntax cleanup, runtime qualification and upstream nonpasses
remain separate work, with [the source inventory](LEGACY-DEFINITIONS.md) recording
the remaining authoring/caller boundaries.

## 3. Whole-family rollout history

The checkpoints below preserve the implementation sequence and the counts measured
at each stage. Current adoption is 110 of 110 ordinary family indexes, as recorded
above. These historical counts do not describe remaining migration work or imply
runtime qualification of every release.

The rollout started with GMP, MPC and ISL. Together with MPFR they exercise the
compiler's real library and bootstrap dependencies. Other libraries, build tools,
runtimes/profiles, compiler, SDK and data entrypoints followed. Construction work
sometimes moved a necessary provider earlier in that order.
The ordinary GMP, MPC and ISL indexes now follow this model across all 21 releases
(three GMP eras, three MPC eras, two ISL eras). Together with MPFR, four family
indexes use the authoring API. Standard build tools select the explicit earlier
native generation, including Gzip for historical source archives.

M4 and GNU Make also use one complete production builder per family, literal
release tables and shared installed/constructor assertions. Source-bound upstream
harness differences stay after the compiled checkpoint. All six supported releases
use the authoring API; M4's two declared-broken releases and the historical
construction recipes remain explicit and unchanged. Ordinary authoring adoption
therefore covered six of the 110 inventoried families at that step. This does not mean all
historical construction callers have left the compatibility API.

Pkg-config and Ninja now follow the same model across their complete six- and
three-release families. Ordinary authoring adoption is eight of 110 entrypoints.
Both use the shared constructor test factory; Ninja keeps its explicit runtime
shell/browser-Python roles separate from build/helper tools. The named Patch role
comes from the preceding bootstrap generation. Historical/direct bootstrap
procedures remain explicit. Pkg-config 0.27's uncached Gettext/JDK/compiler graph is
MIG-011 scope; source adoption does not qualify that release.

The converted indexes now put complete `def` records directly beside their
releases. `mkTable` infers the internal label from the earliest release and supplies
empty dependencies when omitted. Existing named maps remain compatible. This
presentation change preserves the same current artifact/final/test producers.

Autoconf (27 releases), Automake (75), Libtool (11) and GNU Config (one) now use
inline family tables, complete actual-era builders, shared installed controls and
independent checkpoint upstream tests. Ordinary authoring adoption is twelve of
110 entrypoints. All 114 rows evaluate; execution covers only the four latest
packages. Earlier construction factories remain explicitly retained and their
three historical override probes use those factories. The broader Flex observer
nonpass is MIG-012; GNU Config's live edge to old Ncurses is MIG-013.

Bzip2 archive support is centralized in the existing source helper and earlier
tool role. Gzip/XZ helper output remains the same; missing Bzip2 providers fail
closed. One tiny archive fixture verifies the new path.

Zlib (65 eligible releases plus ten unchanged broken exclusions), XZ (39),
Gzip (three) and Bzip2 (three) also use inline family tables. The six Zlib and two
XZ builders represent actual procedures; Gzip and Bzip2 each have one. Shared
production preparation and upstream-script policy are separate files. Production
Zlib builds only installed libraries; upstream examples compile after restoration.
Pager/helper profiles remain finalization or upstream choices. Ordinary index
adoption is sixteen of 110 families; these 110 eligible rows are source-adopted,
not all runtime-qualified. Earlier compression construction and direct standalone
providers remain explicit.

Bison (eleven releases), Flex (four), Gperf (four), PCRE2 (four), Libffi (23) and
Mpdecimal (two) now use the same family model: 22 of 110 indexes and 317 eligible
canonical rows in marked definitions. Actual Bison skeleton and FFI installation
profiles stay in complete independent builders. Test-discovered parser counterparts
and FFI's exact earlier DejaGnu harness stay in U. Runtime/helper edits reuse A.
The full retained factory observer now passes; MIG-012 is resolved with its original
failure retained. The earlier `pkg-config` base role is lazy and separate from
same-named recipe feature options (MIG-016).

GDBM (26 releases), LibYAML (13), Expat (one), Attr (four), ACL (four) and
Libxcrypt (four) raise ordinary index adoption to 28/110 and 369 eligible
canonical rows. Their independent upstream factories restore compiled checkpoints;
production LibYAML excludes test programs and Expat enables its test build only
in U. The existing earlier CMake/Ninja roles are lazy base choices. Current
packages and two historical harness/base representatives pass their selected
leaves; Libxcrypt's exact retained ABI fixture remains pending (MIG-017), so its
normal batch is explicitly incomplete. Retained bootstrap/construction producers
stay exact. MIG-010 and MIG-015 are resolved at their stated scopes; this is not
full catalogue admission or historical runtime qualification.

SQLite (269 supported releases), OpenSSL (215) and Libxml2 (69) raise index
adoption to 31/110 and marked eligible rows to 922/1,515. Their seven broken
records remain explicit exclusions. SQLite's full producer set and both native
OpenSSL production profiles retain exact identities. Changed Libxml2/historical
OpenSSL procedures keep real production/checkpoint boundaries and existing strict
policies. Four selected normal batches and 66 leaves pass; older Libxml2 strict
header parsing remains blocked (MIG-019). Native SQLite/OpenSSL upstream source
reconstruction remains a documented convergence task (MIG-018), not a claimed
checkpoint speedup. Earlier construction/compiler generations stay exact.

PHP (190 releases), Ruby (144 plus its public build-step variant), Bundler (four),
Python (eleven plus the two reduced profiles), and the five compiler indexes now
use inline family authoring: 42/110 indexes and 1,283/1,515 eligible canonical
rows. Public compiler tables retain explicit earlier full-tier construction bases;
public target runtimes remain actual dependencies. Omitted `.instantiate` bases
honor the recipe's chosen base, while explicit caller bases still win.

All thirteen Python production identities, the two native Ruby identities,
Bundler's latest production identities, GCC13/GCC16 and Rust remain exact across
their authoring boundaries. Four current PHP/Python normal batches pass 76 leaves.
Ruby/Bundler and changed compiler qualification are deferred to the assembled
source shape: Rust really depends on the public GCC runtime, so launching that
cold compiler before the remaining dependency indexes are adopted would waste a
build. This is deferred execution, not runtime acceptance. MIG-020–022 record
observer/role repairs, production scaffolding and the retained-generation boundary.

All remaining ordinary indexes now use the same inline model: Tcl/Bash,
terminal libraries, text utilities, JDK support libraries, native utilities,
SDK/Dart/Flutter, build frontends/data and the final Perl/JDK/Node/glibc families.
Measured adoption is 110/110 indexes and 1,515/1,515 eligible canonical releases.
All five public variants evaluate; split coverage remains 1,520 compliant plus
20 unchanged broken exclusions. This completes ordinary index adoption only.

The final source pass checks all 1,535 canonical A/F descriptions and five public
variants, 232 newly adopted rows and their existing test registrations. Captured
closed-compiler/bootstrap/construction/frozen generations remain exact. Active
implicit tool roles now honor runtime provider projections, with unknown names
still rejected (MIG-023). Bounded multi-directory checkpoints support actual
JSON-C/Zstd/Binutils layouts without a new runner (MIG-024). Retained caller
compatibility and remaining isolation work are MIG-025–026. Current package
execution follows against the assembled source shape; historical qualification
and broader admission are not inferred from these counts.

The standalone GMP/MPC/ISL construction calls now share the same complete root
procedures as ordinary packages, with explicit earlier owned bases and shared
independent upstream factories. The duplicate direct `build-steps`/owned ISL
implementations are removed. The intentionally small standalone pure library does
not yet expose the full family facade (MIG-008); importing the final catalogue there
would create a cycle.

Retained GCC library procedures can still use old constructor syntax, but their
compatibility views now select current source-owned compiler/tool providers.
The old Nixpkgs-backed GCC13/GCC16 producer ladder is removed. Requalify affected
release profiles against their actual new inputs; earlier exact-identity snapshots
are not an active requirement to keep the old providers. MIG-005–010 retain prior
construction, locale-fixture and whole-inventory observations without turning those
nonpasses into acceptance.

For each family:

1. Replace layered/remapped definitions with complete inline recipe records in
   a literal release table. Keep genuine compatibility constraints and patches.
2. Supply ordinary defaults with `mkFamily`; remove repeated constructor, platform,
   standard-tool, helper and test-context declarations.
3. Keep complete era builders at the package root. Group stable implementation
   facts in the builder and keep narrow release differences in recipe options.
4. Declare the source resolver and family assertions once. Reuse the existing
   assertions and runner, adapting only their binding to the effective package.
5. Convert every construction caller to explicit earlier-base/dependency
   instantiation. Preserve real user-facing profiles and their differences.
6. Delete obsolete `legacy.nix`, public/construction remapping and duplicate
   `native/`/`ordinary/` procedures only after checking their callers have moved.

This is a family-sized change, not a new task for every couple of versions.
Separate builders only at genuine procedure/interface eras. Helpers may be shared;
one versioned builder must not import or override another.

## 4. Verify the changed boundary and make progress visible

Capture before/after artifact, final, test, alias and construction identities for
the family. If they match, reuse the existing results. If only finalization changes,
reuse the artifact and test the changed final output. If only tests change, run the
changed tests against the cached package. Real compiler/dependency/procedure
changes require the corresponding build and consumer checks.

Use pure evaluation to check default resolution, edits and bootstrap direction;
use tiny fixtures for generic helper changes. Avoid rerunning the full catalogue
for an identity-preserving authoring rewrite. Keep failures and untested versions
visible rather than counting source cleanup as runtime qualification.

Migration status includes a separate evaluated family-authoring view. It follows
registered index/definition origin metadata, reports category and eligible canonical
row counts, and keeps split coverage separate. Retained-recipe availability is not
a remaining-caller count. Compatibility-caller completion, builder verification and
runtime qualification stay unknown until bound measurements exist. A `mkFamily`
marker alone is not proof that callers, builders or tests have been cleaned up.

Status observes declared latest selectors without forcing their test suites. The
actual latest gate still validates producer, suite and batch identities; the
progress command does not imply that gate passed. Text, JSON and `--family` modes
use the same baked facts and perform no store scan in migration mode.

Remove remaining adapters and old registration paths after the final caller moves.
Do not erase required seed providers, historical broken records, patches or real
profiles just because their implementation is old. Existing hardening, historical
failure and admission holds remain separate from this cleanup. Local iteration
continues on Tower with CI and NAS off.

The compiler bases now use actual source-owned providers. GCC4/GCC9/GCC13 raw
compiler procedures have independent A/F boundaries and source drivers, constructed
with the explicit closed GCC16 predecessor. The old borrowed modules and old
GCC13/v2/v3 construction graph are removed. Remaining old recipe syntax executes
through `bases/compatibility.nix` on those selected source providers.

`checks.source-base-providers` rejects a new owned record that merely wraps a
foreign compiler or tool floor. Shared base controls use the existing owned test
factory. These checks do not qualify unbuilt or failed compiler outputs.
The [source inventory](LEGACY-DEFINITIONS.md) records remaining recipe syntax,
caller and test-adapter work; compilation, installed controls and upstream receipts
record execution separately.
