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
