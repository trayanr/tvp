# Security audit roadmap

Provide `tvp audit` in a consumer flake directory. It shares the resolved inventory
behind `tvp used`, identifies upstream components using TVP-owned metadata, and
reports advisory matches per component with links back to the selected output.
Consumers do not maintain package identity maps.

## First implementation

- Reuse the inventory evaluator, including alternate locks, output selection and
  explicit `--impure`; never build application packages just to read selections.
- Add evaluation-only `packageMeta.security` profiles to representative families.
  Record upstream package URLs, CPE vendor/product and supported OSV query
  identities. Unknown mappings remain visible, and ordinary `used`/`diff` output
  stays unchanged.
- Normalize components by exact derivation/output, retaining aliases and use sites.
  Return versioned JSON with the TVP revision, selected attribute, coverage,
  backend/database evidence, advisory IDs, severity, links and upstream fixes.
- Implement Grype and OSV as adapters behind `--backend`. Keep both
  candidates available and choose the default from recorded live evidence. Exercise adapters with offline
  public fixtures and failure cases before live evaluation.
- Mark matches as applicability unassessed. Missing mappings, missing data and
  scanner errors must never become a clean security result. The initial scope is
  declared TVP selections; undeclared transitive dependencies, language locks,
  non-TVP packages and application reachability are explicitly excluded.

## Candidate evaluation

The [first live evaluation](SECURITY-EVALUATION.md) selects Grype as the default
for the current TVP package scope; OSV remains available for explicit comparison.
Repeat and extend the public controls as identity and advisory coverage changes.

Grype is an explicit tooling dependency bundled with the consumer command. The
flake app selects `pkgs.grype` from its locked `nixpkgs` input; Grype is
not a TVP catalogue family. OSV continues to use its public HTTPS API
directly. Preserve the actual scanner version and database/provider evidence in
every report, including after a tooling dependency update.

Run both adapters against the same frozen, public component matrix and record the
actual scanner versions, query identities, advisory data timestamps/digests and
results. A live OSV API response digest identifies the captured response, not a
complete database snapshot. Repeat comparisons using retained evidence.

Include vulnerable/fixed release pairs for Ruby, PHP, Bundler, Curl, OpenSSL,
PostgreSQL and representative native libraries. Include historical release naming,
package aliases, build variants, absent severity/fix data, multiple advisory IDs,
unsupported packages, stale/offline caches and scanner/API failures. Validate
expected findings against upstream advisories rather than treating either scanner
as ground truth. Private application source and fixtures stay outside public tests.

Choose based on verified detection, incorrect matches, missed advisories,
explicit coverage gaps, version normalization, freshness, reproducibility,
offline operation, startup time and maintenance cost. OSV and Grype have different
coverage; retain a complementary adapter if the evidence warrants it. Keep the
selected scanner an explicit consumer-tool dependency rather than adding a TVP
package family solely to support the command. The first recorded comparison used
a source-built TVP Grype; its historical provenance and results remain unchanged.

## Future daily security CI — outside the current implementation scope

Add a separate scheduled job in **tvp-infra** after evaluating the candidates.
Run it every day even when the consumer's flake lock is unchanged: new advisories
can affect a pinned environment. Start with report-only results, separate from
package builds, catalogue/cache publication and deliberate dependency updates.

Each run should:

1. Bind to the consumer revision, selected output, lock digest and exact TVP pin.
2. Refresh advisory data and record its identity and age. A failed/stale refresh
   must be visible; it must not silently report no vulnerabilities.
3. Produce machine-readable and concise human reports, retaining coverage gaps,
   unsupported components, unknown severity and unavailable fixes.
4. Compare with the previous accepted report and highlight new/resolved advisory
   matches and changes in coverage. An unchanged package can acquire a new finding.
5. Retain reports and scanner/database evidence. Add severity/coverage gates only
   after agreeing policy; no automatic dependency updates or merges.

Support the same command in downstream CI with an explicit backend during the
evaluation period. Runtime policy can use `--fail-on` and `--require-coverage`;
infrastructure-owned credentials, scheduling and notifications belong in
tvp-infra. No consumer source tree needs to be uploaded to an advisory service.

## Later scope

- Add evidence-backed TVP vulnerability assessments tied to actual patches,
  versions and build features, using VEX-compatible states. A version match alone
  neither proves reachability nor proves that a TVP patch fixed the issue.
- Expand declared runtime component coverage, including static/vendored inputs.
  A generic traversal of build dependencies must not be called an application
  runtime audit. Keep build/development dependencies distinguishable.
- Add optional Gemfile.lock, Composer and npm adapters as separate dependency
  scopes. Preserve the TVP-only meaning of `tvp used`.
- Compare security results during update previews and group shared component
  findings across application outputs. Whole-environment TVP adoption is a later
  consumer migration, separate from this feature.

## References

- [Grype scan targets](https://oss.anchore.com/docs/guides/vulnerability/scan-targets/)
- [OSV query API](https://google.github.io/osv.dev/post-v1-query/)
- [OpenVEX specification](https://github.com/openvex/spec)
