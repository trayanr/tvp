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
