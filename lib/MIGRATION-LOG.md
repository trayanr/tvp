# Authoring migration execution log

Keep implementation progress separate from runtime qualification and pending
construction activation. The [decision log](MIGRATION-DECISIONS.md) records the
choices that require later resolution. CI and NAS synchronization remain off.

## 2026-11-14 — Base production/test boundary

Merged in [PR #176](https://github.com/trayanr/tvp/pull/176). Retained GCC16 reuses
the complete public procedure, with raw production Python and independent upstream
test tooling. One compiler build passed bootstrap comparison. The installed
consumer, libbacktrace acceptance and GCC known-result gate passed. Historical
19 FAIL / 2 XPASS remain unwaived. The later plugin-header repair rebuilt only
finalization, reusing the compiler artifact.

Local execution records: `reviews/post-migration/base-production-test-separation`
under `~/.local/state/tvp-next-phase/owned-catalogue-migration/`.

## 2026-11-14 — Ordinary GMP family and M4 prerequisites

All nine GMP releases now use the family API, three complete era builders and one
installed test factory. Compilation/installation and output finalization are split;
upstream tests restore the compiled artifact separately. Removed obsolete ordinary
and compatibility overlays. Retained construction remains explicit until the
GMP/MPC/ISL activation batch; both compiler generations and selected construction
GMP outputs remain exact.

The ordinary base's build-only roles now select the explicit preceding native
stage. This removes public-tool cycles through Coreutils → GMP and Gawk → MPFR.
M4 uses those roles; its full authoring conversion is still pending.

Validation scope:

- GMP 5.0.5, 6.0.0a, 6.1.0 and 6.3.0: all 12 installed tests, four upstream
  acceptance leaves and four normal batches passed in 140.692 seconds total.
- M4 1.4.21: nine changed-provider installed tests passed in 0.893 seconds.
- MPFR 4.2.2: its unchanged four installed assertions, independent upstream check
  and normal batch passed with the new GMP/base providers in 31.113 seconds.
- 189 pure contracts passed: 26 GMP, 17 MPFR, 39 family API and 107 effective-input
  assertions, including test-only artifact/final reuse and effective base edits.
- Source split inventory: 1,520 compliant, 20 declared-broken exceptions, no new
  gaps or stale baseline entries. This is not runtime qualification of all rows.

Five other GMP releases remain evaluation-only. Construction activation and frozen
observer decisions remain MIG-005/MIG-007. No compiler rebuild, CI execution, NAS
copy, new platform qualification or whole-catalogue runtime replay was performed.

Commands, timing, source-review findings, exact identities and build outputs live in
`reviews/post-migration/m4-gmp-family-authoring` under the same local state root.
Completed test outputs retain the relevant store closures; there is no second copy
of the compiled trees in the state directory.

## 2026-11-14 — MPC/ISL and grouped compiler-library activation

The complete MPC family (eight releases/three eras) and ISL family (four
releases/two eras) now use the authoring model. Shared root procedures also replace
the standalone GMP/MPC/ISL implementations used by the native/full compiler chain.
The old direct `build-steps` and standalone owned ISL copies are removed.

Completed bounded validation:

- Grouped construction build and all four standalone library upstream gates:
  PASS, 1,015.526 seconds. Both compiler stages were built once.
- Nine public batches: GMP 6.3.0, MPFR 4.2.2, MPC 1.0.3/1.1.0/1.2.0/1.4.1,
  ISL 0.20/0.26/0.28. All 60 named leaves and batches pass. Capability skips remain
  explicit; this does not qualify the other historical releases.
- Native compiler probe, full compiler installed consumer and libbacktrace: PASS.
- Corrected owned MPC runtime/discovery/tool-edit consumer: PASS, 9.518 seconds.
- 240 pure contracts and a separate scoped-inventory laziness probe: PASS.
- Shared `context.mkUpstream` replaces four identical wrappers. All artifact,
  final, raw-execution and acceptance identities remain exact for 30 public
  versions and four construction packages; no replay for that extraction.
- Split inventory stays 1,520 compliant / 20 declared-broken, with no new gaps.

Full GCC upstream acceptance and its normal batch passed. The six complete suite
summaries retain 511,250 PASS, 4,118 XFAIL and 7,237 UNSUPPORTED, with the exact
historical 19 FAIL / 2 XPASS still unwaived; ERROR/UNRESOLVED are zero. The scoped
replacement package/compiler request completed in 1,319.517 seconds. That timing
includes parallel dependencies and is not an isolated GCC benchmark. CI and NAS
remain off; no broader catalogue or strict upstream admission is claimed.

Two scope corrections are retained in the execution record. The first validation
request pulled an obsolete historical GCC13 build through MPC's stdenv-based test
support. That support now uses the effective owned test context, and its dependency
graph excludes that historical GCC13 producer. Replacing the broad request restarted
GCC's upstream capture: another Nix client did not preserve the running execution,
contrary to the initial assumption. Compilation artifacts/finals stayed cached;
completed dependency and test outputs were reused. The interrupted capture is not
qualification evidence. The replacement capture is left running to completion.

Six historical catalogue library producers and frozen Coreutils remain exact.
The frozen locale fixture's public Bash/Perl helper edges drift; original identities
and evidence remain preserved without rebaseline. MIG-008–010 record remaining
capability, historical-helper and whole-inventory boundaries.

Records: `reviews/post-migration/compiler-library-family-authoring` under the same
local state root. Raw test reports and compiled checkpoints stay in the Tower store;
local state retains commands, timings, identities and summaries rather than copies
of those trees.

## 2026-11-14 — M4 and Make family authoring

All six supported releases now use two complete production builders: one for M4,
one for Make. Literal recipe tables retain only actual release differences;
installed and constructor assertions are shared. Build tools come from the effective
base. Upstream preparation/execution/acceptance remains after the compiled checkpoint;
Make's Perl provider is test-only.

Validation completed locally in 112.383 seconds: all six normal batches and all
87 named leaves pass, including runtime-shell/base/tool edits, real C/C++ consumers,
Make's loadable interface/jobserver controls and final-only artifact reuse. All three
M4 upstream suites and Make 4.3 return raw exit zero. Make 4.4/4.4.1 retain the exact
known libc default-PATH echo nonpass, accepted only by their unchanged source-bound
classification policy; it remains unwaived. Guile/VMS exclusions remain explicit.
This is bounded qualification, not universal strict upstream conformance.

Both compiler generations, the bootstrap GNU Make floor, retained construction M4
and Make, frozen Coreutils and both declared-broken M4 releases remain exact. The
bootstrap-pinned Make helpers were not changed. No compiler rebuilt. Split coverage
stays 1,520 compliant / 20 declared-broken; ordinary family authoring is six of the
110 inventoried entrypoints, separate from retained construction conversion.

48 new family contracts and the existing effective-input/17-constructor contracts
pass. Implementation preflight fixed an incorrect pure-module call, a test assertion
that eagerly rejected unrelated edited suites, and a reserved test environment key
before production execution. Formatting preserves all qualified identities. No
extra execution framework, CI run, NAS copy or admission waiver was introduced.

Commands, timings, exact comparisons, root links and results:
`reviews/post-migration/m4-make-family-authoring` under the same local state root.
Completed compiled trees and raw reports stay in the Tower store, with small scoped
roots and no second state-directory copy.

## 2026-11-14 — Inline recipes and whole frontend families

At the owner's request, ordinary definitions now live directly in each `mkTable`
release block. No separate map, lookup key, repeated version or singular wrapper
is needed. `mkTable` infers the label with version ordering and supplies empty
`deps`; named-map compatibility remains. All eight converted indexes use this form.
The shared API has seven additional compatibility/isolation controls; the complete
46-model suite and scoped family/effective-input contracts pass. Repository docs
now show the inline form.

Pkg-config's six releases use three actual procedure eras; Ninja's three use one
complete builder. Both reuse shared constructor controls and independent checkpoint
upstream tests. Patch comes from one lazy earlier-tier role. Ninja's runtime shell
and browser Python are separate from its build/helper providers and change only F.
Retained/direct bootstrap procedures and their pinned inputs remain explicit.

Bounded qualification:

- Five pkg-config releases (0.27.1, 0.28, 0.29, 0.29.1, 0.29.2) and all three
  Ninja releases: 96 named leaves and eight normal batches PASS. Raw upstream exit
  is zero for the existing discovery/charset and syntax groups; full vendored-GLib,
  GoogleTest and PTY coverage is not claimed.
- Six updated M4/Make constructor leaves and batches PASS; their other 81 leaves
  were reused. Make's exact recorded nonpasses and exclusions remain unwaived.
- Latest GMP/MPFR/MPC/ISL normal batches: 25 leaves PASS in
  38.247s after the ordinary M4 provider activation.
  That activation changes public library producer IDs. Earlier historical proofs
  stay bound to their original IDs; they are not silently reused for new producers.
- The inline presentation itself preserves A/F/raw/U for all 30 public library
  versions and four standalone packages against the same current provider graph.
- Both compiler generations, earlier standalone frontends, selected retained
  construction and frozen tools remain exact. No compiler rebuilt. Split coverage
  remains 1,520 compliant / 20 declared-broken.

The first frontend request failed in 55.417s because pkg-config's logging child
shell did not inherit the runner source-root needed by installation. The explicit
export repairs all three procedures. The corrected eight-frontend/six-tool request
passed in 70.815s, reusing Ninja's three completed compilation artifacts. Original
logs are retained; this is not a one-attempt claim.

Pkg-config 0.27 keeps its required Gettext selector but remains uncompiled: its dry
run would activate an uncached public GCC/JDK chain. MIG-011 records that deferred
scope; no dependency was suppressed. Ordinary authoring adoption is eight of the
110 inventoried families. CI/NAS and broader admission remain off/unwaived.

Records: `reviews/post-migration/build-frontends-family-authoring` under the same
local state root, including commands, producer comparisons, timings and scoped
store roots. Compiled checkpoints/raw reports stay in Tower's store.

## 2026-11-14 — Complete Autotools family authoring

Autoconf's 27 releases use two complete procedures; Automake's 75 use three;
Libtool's 11 use five; GNU Config's pinned snapshot uses one. Inline release tables
preserve actual constraints and patch reasons. Stable feature/layout/interface
facts live in the builders. Shared installed pair, historical and split controls
use effective bases; independent U restores checkpoints. The old helper that
replayed compilation for checks is removed. Earlier construction indexes and
factories remain explicit; no old `pkgs` facade is added to ordinary factories.

All 114 rows evaluate with exactly one production split and independent upstream
acceptance. Disabling checks preserves A/F. The existing provider model adds three
Bzip2 controls, and one real tiny tar.bz2 fixture passes. The source helper uses the
same bytes for existing Gzip/XZ commands. Named Bzip2 and Patch roles remain lazy.

Latest GNU Config, Autoconf 2.73, Automake 1.19 and Libtool 2.6.2 pass all 54 named
leaves, independent U and normal batches in 97.685 seconds total, alongside the
small codec fixture. Autoconf groups 1–10 and Automake's three depcomp scripts stay
bounded; this does not certify unexecuted/full upstream coverage. The other 110
releases are evaluation-only in this batch. Both compiler generations, selected
retained Autoconf, earlier frontends, bootstrap Make and frozen tools remain exact;
no compiler rebuilt. CI/NAS and broader admission stay off/unwaived.

The three converted historical factory probes pass all 18 controls. The complete
legacy observer remains red for `flex.defaultIdentities`; its other five Flex
controls pass. MIG-012 preserves that observation without claiming its onset or
silently weakening the full check. MIG-013 records GNU Config's still-live public
edge into historical Ncurses; no retrospective frozen-universe change is made.

Implementation preflight corrected no-op alternate-shell probes and two proposed
Automake contracts: structured flags use the compiler's native channels, and Patch
is checked on a release that actually has a patch. These were evaluation/control
assumptions, not reasons to add flag boilerplate or force unused tools into builds.

Ordinary authoring coverage is twelve of 110 inventoried families, independent of
split coverage and runtime qualification. Records live at
`reviews/post-migration/autotools-family-authoring` under the same local state root;
compiled trees/raw reports remain in Tower's store with scoped roots.

## 2026-11-14 — Complete ordinary compression-family authoring

Zlib's 65 eligible releases use six complete procedure eras; XZ's 39 use two;
Gzip's three and Bzip2's three each use one. Definitions are inline beside their
literal releases with implicit labels and base tools. The ten broken Zlib producer
and status records stay exact. One shared installed suite per family reuses the
existing ABI, symbol-version, format, CLI, helper and customization assertions.
Earlier compression recipes, both compiler generations, standalone CMake inputs,
bootstrap tools and frozen tools remain exact. No compiler rebuilt.

Production and upstream source preparation are physically separate. Zlib A asks
Make only for installed libraries; examples compile in U after checkpoint restore,
then execute sequentially because upstream variants share foo.gz. XZ's test-driver
shell policy also lives in U. Gzip explicitly enables its installed zless frontend
without adding the runtime pager to A; F binds that provider. Bzip2 keeps its actual
installed helper profiles. Twelve tiny source-scope methods pass.

Latest Zlib 1.3.2, XZ 5.8.4, Gzip 1.15 and Bzip2 1.0.8 normal batches pass, plus
Zlib 1.2.5.1 to check the consolidated procedure and repaired version map. That is
71 named leaves and five independent raw upstream exits of zero. The final request
passed in 22.973s. Both Zlib artifacts contain no compiled example/minigzip tests.
The other 105 eligible releases remain evaluation-only here; XZ 5.0.8 is additionally
compiled by the existing format oracle, without its full suite qualification.

Retained attempts are explicit: the first request failed on Gzip's optional zless
installation and an invalid synthetic Zlib shell-frontend assumption; a second
probe still assumed that nonexistent frontend API. The replacement checks the
actual runtime library search path and linked consumer. Historical confinement
fixtures then needed their payload snapshot after deliberate checkpoint removal.
A passing request was followed by source-review findings about Zlib default Make
targets and XZ's build-aux/test-driver. Those were repaired and the affected current
batches rerun. No test failure was converted into a pass by weakening production
validation or rewriting arbitrary unowned script bodies.

The ten broken rows' Gzip consumer-test identities follow the new public Gzip
provider, while their producers, status and other tests remain exact. They were not
executed or retroactively pinned. Source adoption is sixteen of 110 family indexes;
split coverage remains 1,520 compliant / 20 declared-broken. Broader historical and
admission holds remain unwaived; CI/NAS stay off.

Records: `reviews/post-migration/compression-family-authoring` under the same local
state root, including all attempts, identity comparisons and scoped Tower roots.

## 2026-11-14 — Report the authoring phase through migration status

The existing `nix run .#status -- --migration` now reports evaluated family-index
adoption, marked eligible canonical rows and categories alongside split coverage.
`--json` and `--family` retain their meanings. The counts are derived from the
registered namespace tree and explicit mkFamily origin metadata, not source-token
searches or hardcoded totals. Metadata does not enter production construction.

At this point the measured ordinary authoring view is 16/110 family indexes and
269/1,515 eligible canonical rows; split coverage is separately 1,520/1,540 ordinary
rows including five variants and twenty broken exclusions. Retained construction
recipe availability is shown as availability, not as remaining caller counts.
Builder cleanup, compatibility-caller completion and runtime qualification remain
unknown rather than being inferred from origin or split markers.

Status used to force full latest suites and fail on an unrelated Expat assertion.
The new status-only projection validates declared latest selectors without reading
suite/artifact/producer fields. A throwing-field fixture checks that boundary.
Normal latest validation is unchanged; MIG-015 preserves the unrelated nonpass.
Missing facts in old manifests stay unknown and unfamiliar future origin markers
are not counted as adopted. Existing manifest/status JSON fields remain compatible.

The candidate's 53 pure model/origin contracts, 25 Python tests and all 1,520 eligible
ordinary A/F identity comparisons passed without package builds. The actual packaged shell command also passes migration/help/error sentinels and
legacy text/JSON at a mocked closure boundary. Only two CLI installers build
(28.627s including evaluation); the installed migration report takes 0.044s.
CI/NAS and all broader admission holds remain unchanged.

Records: `reviews/post-migration/authoring-migration-status` and the preceding
Autotools `next-authoring-status-candidate` evidence under the same local state root.

## 2026-11-14 — Parser, FFI, decimal, regex and hash family authoring

All 48 supported releases now use inline family definitions: eleven Bison/two
skeleton-layout procedures, four Flex/one procedure, four Gperf/one, four PCRE2/one,
23 Libffi/four installed profiles, and two Mpdecimal/two profiles. Standard tools
come from effective bases; package-specific inputs stay explicit TVP selectors.
The exact earlier pkg-config provider is exposed lazily with its canonical role.
MIG-016 records a caught name collision with Zlib's boolean recipe option.

Shared installed tests retain ABI, closure, variadic, C/C++, static/shared,
serialization, parser/scanner composition and constructor/runtime controls.
Independent U restores completed build trees. Bison/Flex reconfigure in the complete
test-tool environment so counterpart discovery enables real cases; this can
regenerate/recompile check metadata and is not claimed as a free operation.
Libffi keeps its exact earlier DejaGnu/Expect/Tcl harness in U. Decimal's existing
offline check_local scope remains bounded; downloaded corpora are not claimed.

All six latest normal batches pass, with 58 named leaves and raw upstream exits of zero.
The first keep-going request took 179.866s, including real File/Zstd dependencies,
and failed only the two confinement fixtures whose payload snapshot preceded
intentional checkpoint removal. Corrected fixtures/batches passed in 12.946s,
reusing the packages. Bounded source review then found two actual A/U gaps: Flex
prepared tests/ frontends in A and PCRE2's default Make targets compiled internal
noinst test programs. Flex's test preparation moved after U discovery; PCRE2 now
builds installed libraries and its two shipped CLIs explicitly and uses direct
install targets. U keeps the real original test programs/suite. The repaired
request passed in 128.611s, including affected reverse consumers.

Gzip's normal batch and two historical XZ helper controls also pass after their
runtime pager follows the changed PCRE2/Less graph. Their compilation artifacts
remain exact; only runtime suffixes change. Both compiler generations, construction
variants, direct bootstrap compression/frontends and frozen tools remain exact.
The full historical factory observer passes with all six Bison/Flex controls;
MIG-012 is resolved explicitly while its original failure is retained.

The other 42 releases remain evaluation-only here. Authoring adoption is 22/110
indexes and 317 eligible canonical rows; split coverage stays 1,520/1,540 with 20
broken exclusions. No compiler rebuilt. Existing nonpasses, corpus limits and
broader admission remain unwaived; CI/NAS stay off.

Records: `reviews/post-migration/parser-ffi-regex-family-authoring`, including
source-review findings, all attempts, provider comparisons and scoped Tower roots.


## 2026-11-14 — Database, XML and access-control family authoring

All 52 supported releases now use inline definitions: GDBM 26, LibYAML 13,
Expat one, Attr four, ACL four and Libxcrypt four. GDBM retains five actual
procedure eras; the other families each use one complete procedure. Expat's
CMake/Ninja roles come lazily from the existing earlier bootstrap providers.
Historical GCC13 ACL selection, exact library revisions, retained Libxcrypt
4.4.36 ABI fixture, direct bootstrap entry points and frozen construction
providers remain explicit and unchanged.

Production saves the configured/compiled tree; independent upstream execution
restores it. LibYAML's production targets exclude noinst test programs. Expat's
production tests are disabled, with test reconfiguration/build and CTest in U;
that test-parser compilation is real work, not a claimed free checkpoint replay.
GDBM eras without an upstream target report it unavailable. Current installed,
ABI/API, closure, output-reuse and filesystem assertions keep their prior scope.

The first bounded request took 766.386s and failed only four Attr/ACL upstream
preparations and LibYAML's confinement fixture. The former scanned a restored
production tree as a pristine archive and rejected generated include aliases;
the repair validates only the actual upstream frontend subtree. The latter
snapshotted the payload before intentional checkpoint removal. Corrected tests
and seven normal batches passed in 14.356s, reusing production outputs and the
already-passing Libxcrypt raw result. Ninety-four named leaves pass across the
six current packages plus Attr 2.5.0 and ACL 2.3.0 representatives; every selected
raw upstream status is zero. These counts include fixture/constructor controls,
not just upstream cases. Forty-one scoped roots protect 125 valid paths.

Libxcrypt's ABI comparison remains NOT_RUN and its normal batch incomplete:
the exact historical 4.4.36 fixture would realize an uncached GCC16 stdenv
generation. MIG-017 records this separately; the baseline/test is not replaced,
trimmed or marked passed. The other ten current Libxcrypt leaves, including
independent upstream, pass. No compiler rebuild was launched.

Source review additionally found that six LibYAML archives carry test-driver
in config/, which production prepared too broadly. Production now names only
its actual helper scripts; the added compile helper is a literal table profile.
The shared U factory binds test-driver only after restoration. All 13 cached
archives pass production preparation with their test-driver bytes untouched.
The repaired normal request passes in 14.308s, rebuilding only LibYAML while
reusing all other qualified paths. Independent source review has no remaining
material finding.

MIG-010's Ruby/Bundler LibYAML customization assertions and MIG-015's Expat
customization now pass at their stated scopes. Original failures stay retained.
Both compiler generations, historical construction selections, frozen tools,
bootstrap Make/frontends and compression prerequisites compare exact. Authoring
adoption measures 28/110 indexes and 369/1,515 eligible canonical rows; split
coverage remains 1,520/1,540 with 20 broken exclusions. The other 44 family
releases remain evaluation-only in this batch. Broader holds stay unwaived;
CI/NAS remain off.

Records: `reviews/post-migration/dbm-expat-access-family-authoring`, including
both attempts, exact selected paths, source contracts and preserved ABI debt.


## 2026-11-14 — Whole SQLite, OpenSSL and Libxml2 authoring

All 553 supported rows now use nameless inline family definitions: SQLite 269,
OpenSSL 215 and Libxml2 69. Three SQLite, seven OpenSSL and six Libxml2 complete
root procedures preserve real production/profile boundaries. The seven broken
records stay exact. All 553 source/edit contracts, the 215-row OpenSSL contract,
27 isolation contracts and ordinary effective-input/output observers pass.
Independent family source reviews pass. Ordinary test observers follow effective
base roles; the copy-fixture observer now uses the declared override interface
instead of another growing package-name list.

All 270 SQLite production identities (including its broken exclusion) and both
native OpenSSL package profiles remain exact. Libxml2 gains reusable compiled
checkpoints and explicit production-only targets; earlier noninstalled test
programs compile in U. Historical OpenSSL retains its existing specialized T/R/U
protocol and composed seven-flag hardening base. All earlier compiler, native,
construction, frozen and bootstrap identities compare exact. No compiler rebuild
was launched.

The first selected keep-going request took 330.853s, including first realizations
of actual Tcl/CMake dependencies, package builds and upstream checks. Four normal
batches pass: SQLite 3.53.4, OpenSSL 4.0.1, OpenSSL 4.0.0 and Libxml2 2.15.4.
Its only failure was older Libxml2 finalization rejecting a real compiler flag
in xml2Conf.sh. The repair accepts delimited -L/-I metadata spellings while
retaining partial-path rejection. A draft change to the general ELF module was
rejected by identity comparison before any build: GCC also uses that file.
The accepted repair is confined to Libxml2's finalizer; the shared inspector
stays exact. Seven positive/six negative controls and actual metadata pass.

The final-only repair request took 11.250s, reusing every selected A and raw
result. It exposed one test binding gap: the construction libc does not ship ldd.
The existing effective-LZMA assertion now traces the installed xmllint loader
and checks the same exact runtime provider. That corrected leaf passes in the
separate subsecond request; the final 85 selected paths are verified valid without
replaying passing tests. Sixty-six leaves pass across the five selected outputs;
29 scoped roots retain A/F/raw/batches and the older independent leaves.

Libxml2 2.9.14's A/F, ten installed tests and raw exit zero pass, but strict
acceptance rejects its configured header before case classification. MIG-019
records that new reader-grammar gap separately from prior schema/corpus failures.
Its normal historical batch remains red/incomplete. Native SQLite/OpenSSL
source-reconstruction cost remains explicit isolation debt (MIG-018); unchanged
package identities do not make those independent tests free.

The other 548 supported rows are evaluation-only here. Ordinary authoring adoption
is 31/110 indexes and 922/1,515 eligible canonical rows. Split coverage remains
1,520/1,540 with 20 broken exclusions. Retained runtime GNU provider selections,
construction Perl generations, native reconstruction limits and all prior holds
remain explicit and unwaived. CI/NAS remain off.

Records: `reviews/post-migration/xml-crypto-sql-family-authoring`, including
candidate seals, all attempts, source reviews, identity gates and strict failure.


## 2026-11-14 — Runtime and compiler family authoring

- Converted complete PHP/Ruby/Bundler/Python and compiler indexes, with inline
  nameless definitions, literal source hashes, effective-base standard tools and
  shared installed factories. Scope: 351 runtime canonical rows plus one Ruby
  variant and ten compiler canonical rows. Actual compiler/Go bootstrap stages,
  target runtimes and retained construction callers remain explicit.
- Independently reviewed runtime and compiler source candidates. All 351 runtime
  interface rows, ten compiler rows and 55 pure family-model controls pass.
  `.instantiate` now defaults to the selected definition's base and preserves an
  explicit caller base. The earlier source-GNU fallback exposes its existing Gzip.
- Preserved all thirteen Python A/F pairs, native Ruby3/Ruby4, latest Bundler,
  public GCC13/GCC16/Rust, closed full/native compiler and scoped bootstrap,
  construction and frozen snapshots. Coherent selected-shell floors change Go
  and LLVM plans; no cache-only provider substitution is introduced.
- PHP 8.5.12 and Python full/build/minimal current normal batches pass: 76 leaves,
  88 valid selected paths, 12 scoped roots, 231.713s combined. No compiler was
  built. Preserve the original source-only and observer failures alongside these
  results; the scoped admission and suffix-only inspector repairs are MIG-020.
- Deferred Ruby/Bundler and changed compiler execution until the remaining source
  dependencies have their final authoring shape. Dry-run evidence proves Rust's
  real public GCC16 dependency; no intermediate public compiler was launched.
  Current source adoption is 42/110 indexes and 1,283/1,515 eligible canonical rows.
  Split counts remain 1,520 compliant and 20 broken exclusions of 1,540 rows.
- Evidence: `~/.local/state/tvp-next-phase/owned-catalogue-migration/reviews/post-migration/runtime-family-authoring/`.
  CI/NAS remain off; historical, full, hardening and admission holds stay unwaived.


## 2026-11-14 — Complete ordinary family index adoption

- Converted the remaining 68 indexes and 232 eligible canonical releases in one
  assembled source wave. Every ordinary index now uses nameless inline definitions
  beside literal release hashes: 110/110 indexes and 1,515/1,515 eligible releases.
  All five real public variants evaluate. Split coverage remains 1,520 compliant
  rows plus 20 declared-broken exclusions; all-source adoption is not a runtime or
  strict-admission claim.
- Evaluated all 1,535 canonical artifact/final descriptions and five variants.
  The 232 new rows pass seven common interface/edit/split contracts each and
  register 1,780 existing test derivations. Fifty-five pure family controls,
  eighteen provider controls, actual Perl runtime-projection probes and four
  caller-production-patch controls pass. The earlier Perl role equals its pinned
  construction provider; no public provider is silently substituted.
- Captured closed/full/native compiler, bootstrap, construction compiler and
  frozen-tool snapshots remain exact. Readline 2.0/SQLite 3.2.8 still have the same
  broken records/procedures, but follow changed live dependencies; their derived
  identities are not frozen proofs. Preserve the exact scope of that distinction.
- Independent source reviews covered Tcl/Bash, terminal/text, SDKs, JDK support,
  utilities, frontends/data, final five families and the small shared metadata fix.
  Preserve the corrected text-tool report: its original blanket Binutils P1 was
  withdrawn after inspecting active-helper registration. Direct base readers
  remain an explicit cleanup, not a demonstrated all-version failure.
- Source gates caught missing moved helper paths, an incompatible Gettext fetcher,
  missing Readline profile base, stale Curl/Zstd/Tar/Texinfo test wiring and Meson
  runtime-provider edits. Repairs retain the existing assertions. JSON-C/Patch
  production patches now run before configure; only exact known fixture patches
  run after restore. Zstd 1.5.7 U binds CLI test frontends after restore; older Tar
  prepares its tests only once in U. Host checkpoint controls and Tar source
  counterexamples pass; no package build is claimed by those probes.
- Implicit active tool roles now honor accepted runtime-provider projections
  (MIG-023), with a reproduced failing control before the fix, passing controls
  after, and independent review. No per-package runtime-PWD argument is added.
  MIG-024–026 retain bounded checkpoint, compatibility and isolation decisions.
- New code was parsed/formatted and Python sources AST-checked. Nine explicitly
  preserved retained Nix copies were restored after formatting so their sealed
  historical bytes remain intact. Current package/upstream execution is the next
  assembled validation step, reusing all exact cached producers. CI/NAS stay off;
  historical failures, isolation debt, hardening and admission holds remain unwaived.
- Evidence: `reviews/post-migration/remaining-family-authoring/`, including original
  candidates, failed evaluation attempts, corrections, source reviews and final
  source/identity/control records. No intermediate public compiler was launched.


### Assembled validation attempt 001 and Ncurses repair

The committed 110-index shape launched one existing selected-latest workflow.
It stopped after 24.379s in Ncurses 6.6's generated production-Makefile guard,
before GCC compilation. The archive/configure source generates two test-directory
recursions (common targets and module/library targets), while the helper expected
one. The repair removes exactly those two recursions and preserves other source
directories. Four host controls pass, including rejection of one/three matches;
pinned 5.8–6.6 archives confirm the test-module layout. All 293 previously valid
selected outputs remain retained; no fresh selected output or success verifier
was claimed. The original receipt/logs remain under `latest-001`.

The preflight also identifies a separate retained GCC16 required by captured
SDK/JDK bootstrap providers, alongside the public compiler generation. It is an
actual production seed dependency, not another replay of the same compiler.
Keep the preserved providers and realize a required generation once; do not swap
it merely to obtain a cache hit. Libxcrypt's exact ABI baseline remains unchanged.
The next workflow explicitly disables remote builders and substituters and keeps
failed build trees. The first launch inherited host substituter defaults; its
logs/host binding remain retained rather than rewritten as an explicit local-only
request. CI/NAS publication stays disabled.

A separate ergonomics audit confirms 396 inline definition sites across all 110
indexes, with no lookup maps, numeric names, explicit ordinary constructors,
string tool lists or `tvpLib = tvp.lib` aliases. Documentation now qualifies retained
and checkpoint exceptions, labels superseded Libxml2 staging material, updates
the structural tree and repairs three moved links.


### Assembled validation attempt 002 and Automake ordering

The explicit Tower-local request stopped after 32.353s in GNU Sed
4.10, before any compiler recipe started. Direct `all-am` bypassed Automake's
`all: $(BUILT_SOURCES)` barrier, allowing compilation before generated wrapper
headers were ready. The corrected normal `all`/`install` calls use `SUBDIRS=.`
only at the explicitly selected local production recursion boundaries. Existing
production directory order and Findutils's test-program exclusion are preserved.
The same pattern was repaired across 16 complete procedures in eight families.
No C-language downgrade, implicit-declaration allowance, feature cut or test waiver
is used. Original logs and failed workspace remain preserved; GNU Make dry runs
used private copies and do not purport to reproduce a parallel race sequentially.

Focused Sed A/F, upstream acceptance and its normal 7-leaf batch pass in
28.372s. The compiled package and test identities will be reused by the next frozen
assembled workflow. All 297 partial selected outputs remain retained after the
failed request; success-only aggregate verification was not run.


### Assembled validation attempt 003 and independent consumers

All eleven sequential heavy preparation requests passed, including the current
compiler/JDK/LLVM/Dart/Flutter/Node producers and the distinct retained SDK seeds.
The retained GCC16 took 1,520.49s: its logged build phase was 11m39s and its bundled
DejaGNU check phase 10m53s. That old production/test boundary remains MIG-026 debt;
it is not another build of the current separate-U compiler. All twenty selected
heavy production/artifact paths are valid and scoped-rooted.

The normal aggregate stopped at Ninja's jobserver overlap assertion. The fixture
uses 50ms tasks and observed insufficient overlap under concurrent build load.
The selected native harness now uses 1s tasks while preserving every exact
parallel/serial and FIFO assertion. This changes its test derivation only.
Success-only latest verification was not run. Original failed logs and cancelled
workspaces remain preserved; no failed result is accepted or relabeled.

A separate five-profile keep-going request completed Fontconfig, Zstd and Readline
batches, and exposed two independent consumer defects. JSON-C's child upstream
shell did not inherit its checkpoint-root variable; the existing generic checkpoint
consumer now exports that readonly variable before launching the child. Ruby's
manual normalizer imported Python's zlib-backed gzip module even though selected
Gzip was already supplied. Both the ordinary helper and retained public-profile
copy now decompress through that same selected executable. Four plain/compressed
fixtures pass using the exact reduced Python that failed. Heavy and all five
profile artifact identities remain exact across these repairs.

The post-Makefile snapshot preserves all six captured construction/bootstrap/tool
identity groups. Its broader public section changes transitively with repaired
ordinary producers; the initial overly broad equality assertion is retained and
corrected in evidence. No public-identity preservation claim is inferred from the
captured-generation comparison. Current runtime results remain pending the repaired
batches and normal latest verification. CI/NAS remain off.


Attempt 004 reused heavy preparation and reached JSON-C's actual upstream patch.
Its path had been converted with `toString`, dropping sandbox input context. The
upstream command now interpolates the patch path as an input, matching the existing
production-patch handling. A targeted context assertion fails before and passes
after; ordinary/profile JSON-C artifacts stay exact. The first control had an
independent Nix fixture syntax error; that attempt is preserved separately from the
corrected before/after proof. Success-only latest verification was not run.

Ninja's repaired normal batch and Ruby's public-profile batch pass. The independent
GCC batch remains running through this unrelated failure, so its in-flight capture
is preserved. Existing keep-going behavior is used only for the explicit scoped
batch request; the normal latest runner and its fail-fast policy remain unchanged.


### Final named-batch completion and Libtool test fixture

Attempt 005 stopped at one unexpected Libtool diagnostic; the failed normal run
remains failed, without success-only verification. Its test helper selected a
version's first line with `sed 1q`, closing a pipe while Bash's `echo` could still
be writing. A source-bound, test-only patch uses `sed -n 1p` to drain input and
preserve the exact same selected line and stderr assertions. It applies with zero
fuzz to both cached 2.4.7 and 2.6.2 archives. Libtool's A/F stay exact; its existing
normal batch passes in 255.508s including dependencies. Existing expected failures
and skips remain reported; no assertion is weakened or failure reclassified.

The six remaining named package batches (Gettext, Go, Libffi, LLVM, Perl and Tcl)
completed in one independent keep-going request in 789.109s. This request excludes
the known Libtool failure and does not change or bypass the normal latest runner's
fail-fast policy. It lets independent results finish once. These timings overlap
other requests and must not be summed as elapsed user time.

The separately held GCC16 normal batch passed; raw make exited zero, and raw/audit
outputs are valid and scoped-rooted. Historical nonpasses and broader limits remain
unwaived. All five public-profile batches pass with exactly 60 expected links and
75 valid, scoped-rooted artifact/final/batch/leaf paths. Corrected JSON-C ordinary
and profile batches pass in 12.495s, reusing A. Original failed focused-request
receipts retain their two old JSON-C failures; matching passing results are adopted
only from the repaired targets.

LLVM's existing U consumer was observed unpacking/configuring a separate tree and
recompiling production objects with tests enabled. This is explicit MIG-026
checkpoint/performance debt; production A/F were retained independently. Do not
claim all test-only edits reuse every compilation, or count whole request duration
as exclusive upstream execution. The final normal latest aggregate and its success
verifier are run separately after these concrete named batches finish. CI/NAS stay
off; no historical all-version execution or full admission is claimed.


### Normal latest verification and completed ordinary authoring scope

Attempt 006 on code commit `524e24c7a5ca9d08ca03ab3b6f327f68a3680d8c`
passed start/wait/success-verification with exits 0/0/0 in 14.570s. The verifier
confirmed 1,191 valid selected outputs and 1,071 exact links across 110 families
and 961 named tests. This final aggregate is availability verification over the
matching earlier executions, not 961 new executions. All declared siblings are
valid. The five separately verified public profiles contribute 60 exact test
links and 75 retained paths; these counts are not added as unique fresh tests.

The actual offline status app passes and reports all 110 ordinary indexes and
1,515 eligible canonical rows adopted. The 1,540-row split inventory is 1,520
compliant plus 20 declared-broken legacy exclusions. Runtime qualification and
construction cleanup remain separately measured; source/index adoption does not
silently mark them complete.

All 116 artifact outputs of the 110 selected current packages and 54 immediate
upstream-named execution inputs are explicitly scoped-rooted (170 paths), in
addition to the workflow/runtime and profile roots. Retaining only F could lose
reusable compilation checkpoints during later GC. This retention queried/realized
already valid paths with builds and substituters disabled; it did not compile,
fetch or copy data to NAS. The raw GCC capture is also retained explicitly.

The final documentation-only receipt update adopts the exact verified package,
test-batch and public-profile identities, checked again at evaluation scope.
Historical/unselected releases, retained caller migration, recorded checkpoint
reconstruction and pre-split checks (especially LLVM and the retained GCC seed),
known upstream nonpasses, hardening and full/admission gates remain unwaived.
CI/NAS remain off under the owner-approved migration policy.

### Compiler-family bases, lazy providers and effective-context status (2026-11-15)

Implemented the agreed base-interface refactor from
`8e9120c776fb0c2f962dd2a7754fec6ae58ada7d`. Public selection is now
`tvp.bases.gcc13.full` or `tvp.bases.gcc16.{seed,runtime,reduced,full}`;
`tvp.bases.default` selects GCC16 full. System selection resolves once at the
root, and executable providers live in one lazy `tools` catalogue. The selected
`tools.gcc` is the complete driver; generic aliases follow it. Unsupported partial
Binutils/libc substitutions fail rather than changing metadata alone.

Pinned live retained callers to private legacy selections before changing the
public default. Existing graph/provenance protocols continue receiving their
original flat records; ordinary family instantiation uses the new public context.
The public `baseTiers` namespace is removed. Old `standardTools` inputs remain a
single compatibility boundary while construction/test callers finish migrating.
New stage definitions use named tool records and internal `mkStage` composition.
No package versions, source hashes or actual compiler construction edges changed.

Initial identity comparison caught unintended replacement of OpenSSL's explicit
linker contribution, propagating to retained Ruby/Bundler. Preserving that fixed
baseline contribution restored all captured identities. Independent source review
also found no-op provider-metadata loss and complete-edit deletion semantics;
focused regressions now cover the repairs. Actual packaged status testing caught
Nix JSON's automatic `outPath` coercion; provider records now use `path`, with a
Nix serialization/laziness regression as well as Python renderer checks.

Validation is bounded to this refactor: 161 pure base/provider/family contracts,
17 actual MPFR family assertions, 32 status tests, and evaluated base-selection,
native-platform and owned-catalogue contracts pass. Two tiny C/C++ compile/link/run
probes pass with the existing GCC13 and GCC16 drivers. All 1,794 existing graph
entries and captured canonical/variant artifact/final identities remain exact.
The original construction snapshot failure remains recorded separately (MIG-027).

The normal latest aggregate is fully cached: 1,190 required outputs plus the
aggregate (1,191 total), with 1,071 exact family/test links across 110 families.
No package test suite or compiler was rebuilt for this availability check.
Public-profile batches likewise reuse their existing outputs. Status text, JSON
and family filtering now show the effective platform/toolchain and used providers;
old manifests retain explicit unknown context information.

Logs, comparison receipts and bounded probe evidence are retained under
`~/.local/state/tvp-next-phase/base-interface-refactor/20261115/`. CI and NAS remain
off. This is structural/source validation and cache reuse, not new historical
all-version qualification or full admission. MIG-025/MIG-026 and historical
nonpasses remain unwaived.

### Subsystem entrypoint composition (2026-11-15)

Moved public family/platform/default selection into `bases/default.nix`, and kept
retained construction in `bases/retained.nix`. GCC16's full-stage defaults now
refer directly to its local earlier stage. Package selector/alias projection,
CLI assembly, check registration, test batch/latest registration and evaluated
reports now live in their respective module entrypoints. Audit fixture provider
wiring lives in `tests/support.nix`; ordinary package tests remain with their
families. Root `default.nix` is 142 lines of shared-context wiring and exports,
replacing its previous 1,008-line mixture of composition and subsystem policy.

Captured pre-extraction selectors and outputs before editing. All public export
names and check names are exact. All 2,062 package selectors (including selection
metadata), all six CLI derivations and the latest aggregate are exact under the
same source binding. All 1,794 existing graph entries, canonical/variant A/F
identities, four source stages and four retained input contexts are unchanged.
Status facts and the three scoped base/platform/catalogue checks are identical.

Existing validation passes: 161 pure base/provider/family contracts, 17 MPFR
assertions, formatting and whitespace checks. Independent read-only review found
no actionable issue with relative paths, private exports, earlier-stage selection
or lazy report/test wiring. Latest and all five public-profile batches are
realized from cache with builds and substituters disabled; no compiler or package
suite is rebuilt. The offline status app is checked separately against the new
source tree. No new test framework or package-specific procedure was added.

Compact comparison receipts and the before/after root wiring are retained under
`~/.local/state/tvp-next-phase/module-entrypoints/20261115/`. Existing historical,
construction snapshot and JDK audit limits remain recorded in MIG-027; their
baselines are not rewritten. Changes remain local and uncommitted. CI/NAS remain
off under the existing migration policy.

### GCC13 owned contexts and historical compiler usage (2026-11-15)

GCC13 now declares and composes its actual stage contexts through the same owned
base/stage API as GCC16. Its family exposes `seed`, `libc`, `shell`,
`compilerPreparation`, `compiler`, `toolFloor` and `full`. Full-stage composition
lives in `bases/gcc-13.3.0.nix`, rather than arriving as an already-completed argument.
The retained construction creates local owned contexts before instantiating MPFR;
both shell/compiler MPFR callers now consume them. Other retained producer recipes
remain pinned on the older implementation, explicitly recorded in MIG-029.

Audited GCC9 and GCC4.9 through source and evaluated declarations. Their only
recipe consumers are eleven declared-broken releases: Readline 2.0 and ten Zlib
0.x releases. Both still register eight own base tests, full/all batches and
historical graph/baseline records. No supported canonical, public variant or
retained construction variant selects them. They remain private; nothing was
silently dropped from the historical validation scope. Corrected the stale Zlib
comment: its actual status already records a GCC <= 3.3 requirement.

Captured raw stage drivers, Binutils/libc and ordered baselines, internal MPFR A/F,
seed tool roles and the full tools/platform/reference interface before edits.
All remain exact afterward, as do captured canonical/variant A/F and retained/source
context providers. The 1,794-entry production graph is unchanged. Updated source
contracts verify the real stage lineage, actual MPFR consumers, all stage platforms
and the exact broken-only old-compiler caller set. Existing 161 pure contracts,
17 MPFR assertions and scoped base/platform/catalogue checks pass.

The registered `gcc13-stage-contexts` check reuses the existing owned test factory.
All seven contexts compile, link and execute a small C program; full also compiles
and runs C++. Its dry run contained only tiny check/runner/script outputs, and
execution passed without compiling any provider or package. Latest and all five
public profiles remain cached with builds/substituters disabled. Independent
read-only source review found no actionable issue with provider selection, local
cycles, baseline/reference preservation or scope claims.

Evidence and the old-compiler inventory are retained under
`~/.local/state/tvp-next-phase/gcc13-stage-contexts/20261115/`. Changes remain local
and uncommitted. CI/NAS remain off. Legacy producer conversion, the historical
construction snapshot and JDK audit assertions, and broader qualification gates
remain pending and unwaived.

### Owned base declarations and remaining-definition screen (2026-11-15)

Converted GCC13, GCC9 and GCC4.9 to authoritative owned base definitions. Removed
all `mkBase` definitions/calls, including the retained GCC16 declaration. Seven
checked `legacyEnvironment` projections remain for actual retained stdenv callers;
`construction.ownedBases` selects their existing owned declarations directly.
GCC13's full definition is composed locally before the compatibility projection.
GCC9/GCC4.9 expose only their actual full borrowed contexts. Named external seed
providers preserve the original Make/File generation and ordered tool floor.

Migrated the eleven historical public callers to owned split recipes while
preserving hashes, broken statuses and the original source defects. Reused the
historical Zlib test body rather than modern shared-interface assumptions. The
split report now passes with 1,531 compliant rows and nine explicit exceptions,
zero stale/unbaselined entries. This is source/plan compliance; all twenty broken
statuses remain. No historical package was fetched, built or relabeled qualified.

Validation: 188 pure controls and five registered base/platform/catalogue checks
pass. All 24 shared checks run through the owned test factory on GCC13/GCC9/GCC4.9
and pass, including real C/C++, hardening, response-file, static-link and floor
execution. Dry runs contained only tiny test/script/check outputs; no compiler or
provider was rebuilt. Captured supported canonical and public-variant A/F and
retained/source context providers remain exact. The 1,794-entry production graph
changes only the eleven intentional broken package entries. Existing latest and
five public-profile batches remain available with builds and substituters disabled.

Added a rerunnable Python/Git source screen and the compact
`LEGACY-DEFINITIONS.md` report. All 110 ordinary entrypoints use `mkFamily`, but
130 retained package files still call `mkDefs`, 87 declare `packageArgs`, and 152
package producer files call `mkDerivation`. The inventory records static references
and deliberate test/caller bridges; it does not certify runtime liveness or full
producer conversion. These remaining definitions are explicit follow-up work.

Compact comparison/validation receipts are retained under
`~/.local/state/tvp-next-phase/base-definitions/20261115/`. Readline2.0 and Zlib0.x
source archives were unavailable locally, so their new preparation/finalization
procedures remain runtime-unqualified. Existing construction snapshot, JDK audit
and broader historical/admission holds remain unchanged. Changes are local and
uncommitted; CI/NAS remain off. MIG-030 records the decisions.

### Versioned base selectors and latest-major aliases (2026-11-15)

Registered exact GCC base families with package-style version names and major
aliases. `gcc_4` currently resolves to `gcc_4_9_4`; `gcc_9`, `gcc_13` and `gcc_16`
resolve to 9.5.0, 13.3.0 and 16.2.0. Selection uses numeric version comparison over
the explicit table. Public callers and current documentation use those major
aliases. `default` remains `gcc_16.full`. Private retained IDs and historical
records keep their original spellings and physical provider choices.

All 198 pure controls pass, including ten new selector cases. Actual base/platform,
owned catalogue, compatibility/shared-suite and alias checks pass. The dry run
contains only two new tiny check outputs; no provider or package is rebuilt.
Captured canonical and variant A/F and retained/source contexts are unchanged;
the complete 1,794-entry production graph is exact, including all broken entries.
Split compliance remains 1,531/1,540 with nine explicit exceptions and no stale
baseline records. Existing upstream, historical, construction and admission limits
remain unwaived; CI/NAS remain off.

Compact receipts are retained under
`~/.local/state/tvp-next-phase/base-aliases/20261115/`. Changes remain local and
uncommitted. MIG-031 records the naming and alias policy.

### Base filename and identifier cleanup (2026-11-15)

Renamed the four compiler-family entry files to explicit release names and moved
GCC13's local stage/full helpers under `bases/gcc-13.3.0/`. Updated imports, links
and current documentation. Renamed the owned/retained GCC4/GCC9 IDs and all their
callers, graph/status keys and fixture keys to `gcc_4_9_4` / `gcc_9_5_0`.
The user's direction is to improve current naming rather than retain old IDs for
historical compatibility; MIG-032 records that policy. External Nixpkgs attribute
names are its API and are not renamed.

All captured package A/F, variants and compiler context providers stay exact.
All common entries in the 1,794-entry graph stay exact; two retained base keys
are explicitly renamed, with unchanged provider paths. Existing upstream and
runtime qualification limits are not altered. Source files are intent-added so
normal Git-backed flake evaluation includes the new modules without committing
the working changes. CI/NAS remain off.

Compact validation receipts are recorded under
`~/.local/state/tvp-next-phase/base-filenames/20261115/`.

### Replace borrowed base providers with actual source builds (2026-11-15)

The previous base-interface pass left GCC4.9/GCC9 and the GCC13 seed on Nixpkgs
providers. That was incomplete migration. Removed those borrowed modules and the
old GCC13/v2/v3/GCC16 producer ladder, updated active callers, and removed obsolete
identity checks that required preserving the foreign generations. Existing upstream
failure/hardening gates are retained.

The four public families now select actual source-owned executable providers.
The base registry needs no `pkgs`; all four also evaluate with the standalone owned
library. GCC4/GCC9 use independent source procedures on the explicit closed GNU16
predecessor. Their real archive patch/preparation and sandbox configure controls
pass; neither compiler is built or qualified. GCC13 has a real source composition
and one produced full stage. Remaining old recipe syntax executes through the local
constructor on source-owned providers; it is still explicit authoring debt.

GCC13 initially exposed header-order and libc-sysroot assumptions in its retained
recipe. After correcting them, its bootstrap comparison, install and checkpoint
passed. Finalization then exposed an ELF inspector assumption about non-text
configured-prefix bytes. The scoped finalizer repair preserved the successful A
exactly; only F/driver and tiny scripts rebuilt. Current A/F/driver are valid and
have three scoped retention roots. Fresh legacy C/GMP/C++ execution passes for
GCC13 and GCC16. Each common base suite passes seven of eight leaves; its bind-now
assertion still fails and remains open. No qualification is inferred for the old
compilers or for all downstream packages.

198 pure controls and nine source-GCC13 composition contracts pass. Root integration
evaluates all ordinary entries, the registered selection/platform/catalogue checks
and seventeen MPFR assertions. The provider gate checks 45 production providers
and sixteen active source modules; seven focused mutation controls pass. Normal
Git-backed flake evaluation includes the new files. Split coverage remains
1,531 compliant / nine explicit debts / 1,540 rows, with twenty declared-broken
statuses. Removing obsolete construction variants reduces the graph to 1,549
entries; old graph-identity preservation is not a requirement for this correction.

Source review found no material remaining provider/finalizer defect. Complete
compiler conformance, changed consumer qualification, the bind-now/hardening gate
and existing historical/admission holds remain outstanding. Local source edits
remain uncommitted. Compact receipts and build-log references are under
`~/.local/state/tvp-next-phase/source-base-providers/20261115/`.
CI and NAS remain off. MIG-033 records the decisions and superseded claims.


### Uniform family and construction-caller cleanup (2026-11-15)

Converted all 110 ordinary indexes to independent current family definitions.
Removed captured old tables, constructionRecipe exports and repeated tool floors;
construction and variant callers now select the current procedures explicitly.
All 1,535 canonical rows plus five public variants are structurally split-compliant.
The last nine baseline exceptions are removed; all twenty broken statuses remain.

Removed 136 old indexes and their audited 559-file closure, then six unused caller
factories and four stale stage READMEs. Active source-bootstrap procedures remain
protected. Updated dynamic X11, SDK, compiler, Ruby and shared test observers to use
actual current providers instead of testing for deleted constructors or fabricated
libc outputs. Native versioned builder checks now recognize complete `build.nix`
and current naming suffixes; GDBM's earliest shared era is named for 1.8.1.

The base owns standard tools and platform facts. File is an earlier source-built
provider; Go/LLVM/JDK platform strings and CPython tool aliases leave the release
records. Genuine construction roles and public profile differences remain explicit.
Shared family test overrides and owned runtime-reference auditing replace duplicate
caller factories. Generic metadata allows unused registered tool projections to stay
lazy while unknown roles still reject; actual grouped edits remain coherent.

The final catalogue, source inventory, checks, pure controls and bounded execution
receipts are stored under `~/.local/state/tvp-next-phase/package-uniformity/20261115/`.
Runtime closure acceptance and absent-library rejection use only tiny fixture/test
outputs on cached providers. Compiler/stage identities compare exact after the
shared test machinery changes. Changed ordinary inputs are recorded separately;
old results are not silently reused for newly selected tools or source fetchers.

One shared-script formatting mistake launched an unintended prerequisite rebuild.
The request was cancelled after 152 derivation starts, with no compiler producer
started. Corrected shell bytes restore the original compiler hashes. The cancelled
log and final bounded plan are retained in the receipt references, not hidden.

This completes the current ordinary-family authoring/caller cleanup, not global
runtime qualification or source-bootstrap redesign. Mirror/retry/Git source backends,
upstream reconstruction debt, unbuilt compilers, hardening and historical/admission
holds remain explicit and unwaived. CI/NAS remain off. Changes remain local and
uncommitted. MIG-034 records the decisions.

## 2026-11-16 — Shared helper consolidation

Implemented MIG-035 in the existing authoring worktree. Removed49 duplicate helper
files; shared34 restore implementations, six loader-aware auditors and three prefix
relocators.78 restore steps and37 loader-aware checks use shared step helpers.
159 equivalent command constructors now use the shared editable-record constructor.
13 tracker normalizers share archive-name parsing, and75 unused package-set arguments
are removed. Shared lazy fixtures honor effective tools and caller overrides.
Nixpkgs-backed test construction now has an explicit compatibility namespace.

Bounded validation:104 registered checks evaluate;38 pure helper contracts pass,
including104 old-parser comparisons;12 filesystem controls pass directly and in
an owned sandbox using cached tools.32 migration-status unit tests pass. The
sandbox built only its step script, runner and test output. No package, compiler,
fetcher, aggregate or full/latest execution was requested. Compiler-base provider
identities match all14 recorded comparisons. Shared output-helper changes propagate
through dependent package derivation identities; this is recorded for later runtime
qualification, not described as cached execution or a full migration acceptance.

Retained decisions:73 specialized constructors,38 custom tracker normalizers and
13 provider-specific restore records remain explicit. The duplicated OpenSSL/SQLite
production savers stay parked to avoid an incidental481-release compilation-input
change. The GNU locale-data source remains explicitly fixed; broader libc/architecture
selection remains separate. Existing hardening, historical and runtime qualification
holds remain unwaived. CI/NAS stay off.

Evidence: `~/.local/state/tvp-next-phase/helper-consolidation/20261116/`.

## 2026-11-16 — Compiled helper verification

After compilation was authorized, ran a Tower-local13-version matrix covering
GMP6.3.0, MPFR2.4.2/4.2.2, Gperf3.3, Bison3.8.2, Flex2.6.3, Attr2.6.0,
GDBM1.26, Ncurses6.6, Readline8.3, Gawk5.4.1, Sed4.10 and Zlib1.2.3.4.
All13 normal batches and135 named tests pass.124 current tests executed fresh
across the run;11 were preexisting cached results. All13 upstream leaves passed.
Six selected compilation artifacts and10 final packages built fresh; seven A
artifacts and three final packages were reused.148 selected test/batch outputs,
135 exact batch links and all26 selected A/F outputs were verified and retained.

Flex2.6.3 exposed an existing production/test-boundary defect: top-level make all
unconditionally generated test parsers requiring an undeclared yacc. Production
now removes tests only from its generated top-level Makefile recursion; upstream
configure restores the full test layout in the private checkpoint workspace, where
Bison is declared. The first command-line SUBDIRS repair propagated recursively
and failed; it was replaced by the guarded top-level rewrite. Original failures
and all three frozen attempts remain recorded. Five filesystem controls, all four
actual source templates, the15 parser-family contracts and an independent source
review cover the repair.104 registered checks still evaluate and all14 recorded
compiler-base/stage identities remain unchanged.

Build requests ran serially with four cores, local builders and empty substituters.
No compiler toolchain rebuild, CI, NAS access, all-version run or global qualification
is claimed. Evidence and scoped roots:
`~/.local/state/tvp-next-phase/helper-consolidation/20261116/compilation-verification/`.
