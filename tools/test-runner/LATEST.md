# Latest ordinary releases first

`tvp.lib.tests.selectLatest { canonical; packages; batches; }` is a pure Nix
projection. It returns `batches` (the existing batch derivations, keyed by canonical
job name) and context-free `metadata` (`tvp.latest-tests/v1`). It uses each family's
public alias and verifies the semantic version maximum among non-broken ordinary
releases. Degraded releases remain eligible. The selected batch must retain the
package's exact own-test suite and named outputs; it keeps its builder/testContext.

Missing or inconsistent aliases, missing batches and selected releases without
tests are evaluation errors. An empty catalogue yields empty selections. A family
with only broken releases is recorded in `metadata.skipped` with each declared
reason and required repair. Families absent from `canonical` are outside this
catalogue's coverage. Historical tests and outputs are not inspected by selection.

Inspect or build locally (these commands can select expensive dependencies):

```sh
nix eval .#latestTests.x86_64-linux.metadata --json
nix eval .#latestTests.x86_64-linux.batches --apply builtins.attrNames --json
nix build .#latestTests.x86_64-linux.all --no-link
# Or one selected existing batch:
nix build .#latestTests.x86_64-linux.batches.gnumake_4_4_1 --no-link
```

`latestTests.<system>.all` uses the existing owned batch constructor. It is separate
from `testBatches`, `testPlans`, and the full runner's job collection. There are no
implicitly selected variants, retired construction/bootstrap test suites, base suites, repo
checks or full runtime-ownership exports. Meaningful extra checks/profiles must be
requested separately after inspecting their dependencies. Ordinary suites retain
their declared transitive inputs, including compatibility and historical test
dependencies; selection does not rewrite those dependencies.

Here "ordinary" means members of `canonical`, matching the existing catalogue's
family policy. This includes explicitly catalogued seed/profile families such as
`jdk-bootstrap` and `python-build`; their declared versions and dependencies are
unchanged. It does not include the separate `bootstrap-*` construction batches or
`variant-*` jobs.

Nix identities and normal cache reuse decide what needs rebuilding. Existing graph
and dependency reports remain diagnostics. Latest compatible moving dependencies
advance through their existing aliases; measured major/minor constraints, exact
exceptions and independent bootstrap seeds remain intact.

CI remains OFF until the whole migration is complete. A future, separately reviewed
two-stage job can use the same pinned source for both commands:

```sh
set -eu
nix build .#latestTests.x86_64-linux.all --no-link
# Reached only after the latest stage succeeds; separately requested full coverage:
nix build .#testBatches.x86_64-linux.all --no-link
```

Use normal Nix fail-fast behavior (`keep-going = false`); do not add `-k` to the
latest stage or launch both stages in parallel. Already running sibling builds
may finish when a test fails. Latest-only success is partial coverage and cannot
satisfy the existing full-only protected status. The frozen full runner and
representative certificates retain their existing semantics.

On Tower, Make/M4 changes can still invalidate expensive consumers selected here.
If selected expensive application dependencies are actually missing, build those
applications separately and sequentially first. Keep normal inner compiler
concurrency and normal small-build concurrency; do not change max-jobs/cores.
Evaluation fixtures do not build those applications.

The pure selection contracts can be evaluated without realizing the catalogue:

```sh
nix eval --impure --json --expr \
  'let f = builtins.getFlake (toString ./.); in import ./lib/tests/latest.nix { inherit (f.inputs.nixpkgs) lib; }'
```
