Representative validation is a partial attempt with `full=false`. It selects one
latest applicable ordinary release per family through the release-table aliases,
plus explicitly reasoned current profiles, contract checks and compatibility
cases. The catalogue entries and all-version test plan remain available.

At a fixed committed revision, evaluate `testPlans.<system>.text` and
`testCatalogues.<system>.text`. The latter records the actual family aliases,
complete eligible version identities, public profiles and all declared package
outputs without retaining package-output contexts. A reviewed selection manifest
(`tvp.representative-selection/v1`) binds their SHA256 hashes, subject and exact
selected/omitted job lists. Its `families` map must equal every catalogue family
alias. `profiles`, `compatibility` and `checks` are lists of `{job, reason}`;
`omittedOrdinaryVersions` counts eligible versions outside the selected jobs.

Pass each selected exact job name with a separate `start --only JOB`, then use
that run's frozen `wait`. Select `check-package-runtime-ownership-latest` and
`check-runtime-policy-latest`. The existing `check-package-runtime-ownership`
exports all historical roots and is deliberately forbidden in this scope.
Inspect other checks' actual dependencies before selection: selecting a check
does not narrow its transitive inputs. Retained host tools and bounded alternate
provider fixtures need explicit reasons when they are compatibility boundaries.

The frozen runner's `verify-representative` requires `--run`, `--reference-plan`,
`--catalogue`, `--selection-manifest`, `--expect-revision`, `--expect-source`,
`--expect-system` and `--output`. It requires the exact selected projection,
terminal partial state, complete selected output bindings and links, and strict
selected runtime ownership with unchanged reviewed baseline rows. It never
requires or certifies the full aggregate. Missing or extra historical jobs,
wrong aliases, cancelled/retried evidence and partial output sets fail.

The original `verify` remains full-only. A representative certificate cannot
satisfy a hosted status whose policy still means full catalogue validation.
Trusted controller and required-context activation are separate reviewed work.

For a reusable Nix selection and separate local latest-first build target, see
[LATEST.md](LATEST.md). That target does not add the representative profiles or
checks above, nor change the frozen runner or full plan.
