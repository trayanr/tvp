# Latest ordinary releases first

`tvp.lib.tests.selectLatest { canonical; packages; batches; }` is a pure Nix
projection. It returns `batches` (the existing batch derivations, keyed by canonical
job name), context-free `metadata` (`tvp.latest-tests/v1`), and `requiredOutputs`
(context-bearing paths for all selected package, batch and named-test outputs).
It uses each family's
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

`tvp.lib.tests.mkLatest { context; selection; }` uses the existing owned batch
constructor and explicitly requires every declared output, including siblings
that cached suite links do not retain. `latestTests.<system>.all` uses this helper.
It is separate
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

## Reusable local workflow

```sh
nix run .#test -- latest --flake . --state-dir /absolute/new-run --json
nix run .#test -- latest status --run /absolute/new-run
nix run .#test -- latest wait --run /absolute/new-run
nix run .#test -- latest --resume /absolute/new-run
nix run .#test -- latest stop --run /absolute/new-run
nix run .#test -- latest verify --run /absolute/new-run
```

`latest` launches and returns JSON; `wait` is a read-only observer with changed-state
progress and a 60-second heartbeat. Closing it or interrupting it leaves the worker
running. `--state-dir` is one run's exclusive directory, not a movable latest alias.
A local flake must be clean and committed. The command snapshots it once, records
its revision/tree/system, and obtains all selection/output identities from the
existing Nix `latestTests`. Resume uses that frozen snapshot even after a branch
moves; an explicitly different `--flake`, `--system` or `--expect-source` is refused.
Resume reconnects to a healthy worker without creating another attempt.

The default backend requires native Linux user systemd. The launcher discovers
`/run/user/UID/bus` when session variables are absent, or respects configured
`XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS`. Host Nix/systemd executables are
resolved and recorded; no new nixpkgs runtime dependency is added. A transient
USER unit runs with `Restart=no`, `KillMode=control-group` and a finite
`RuntimeMaxSec` (default eight hours, configurable with `--deadline` in seconds).
The worker also has a signal-aware deadline and bounded client shutdown. No
permanent service, timer, Nix concurrency setting or CI configuration is installed.
`--foreground` explicitly selects a non-durable synchronous backend if needed.

Preflight performs one recursive native derivation query and batched local-store
validity checks. It accepts native v4 and the old unversioned derivation schema;
unknown schemas, missing nodes and unresolved demanded outputs fail with diagnostics.
When native JSON omits a fixed-output path, preflight resolves only demanded
single-output fixed derivations using read-only `nix-store --query --outputs`.
It records that native evidence and batches newly resolved validity checks per
dependency frontier. Cached ancestors stay pruned. No build, fetch, `env.out`
guess or output-path hash reconstruction is used; genuinely deferred/dynamic
outputs remain unsupported and fail closed.
Exact `pname`, `version` and application name metadata identify GCC/LLVM/JDK/Node/
Dart/Flutter applications and their declared seed/compatibility producers. Tests,
wrappers, source archives and fixed-output artifacts are excluded. Unknown origin
is not an error or an origin claim. Already-valid demanded outputs prune their
ancestors, so missing historical dependencies of cached applications are not
rebuilt. Needed heavy producers run one at a time, dependencies first, requesting
only demanded named outputs. Inner builds and normal small builds retain the
caller's normal Nix concurrency. Heavy preparation is not downstream test proof.

For selected heavy families, the frozen descriptor supplies the exact application
producer and version when native derivation labels are absent. Present labels must
agree; missing labels cannot remove a selected application from preparation. A
sequential final-output request also realizes its demanded split artifact; the
runner does not guess an artifact producer from its name.

Only after the heavy gate does one fail-fast realization request run. It includes
the aggregate and exact output selectors for any missing selected packages, batch
outputs or named-test siblings. A cached aggregate cannot restore dependencies
that its runtime links do not retain, so those selectors remain explicit. The
pre-request availability and target list are recorded and bound to verification.
Verification checks every selected package, batch and named-test output, all
siblings and exact aggregate/batch links. Valid outputs are rooted in batches;
root stdout is interpreted as root *names* and their actual symlink targets are
checked. A store text manifest retains the recipe graph without realizing its
`.drv` files. Source, copied/sealed worker and observer modules, interpreter and
host interfaces remain bound to the run. Roots are run-owned for future lifecycle
adoption; this command does not delete roots or certify long-term retention.

`--cached-only` refuses to launch unless every selected output **and the aggregate**
is already valid and there are zero required heavy requests. It rechecks this
inside the worker. This is useful for runner integration testing without allowing
new application builds. Availability, cache reuse and fresh execution are reported
separately; latest success neither recertifies known bounded upstream nonpasses
nor constitutes full coverage, recipe approval, strict conformance or CI readiness.

An infrastructure interruption permits one **explicit** retry:

```sh
nix run .#test -- latest --resume /absolute/new-run --retry-interrupted
```

There are at most two attempts against the unchanged frozen source/code/commands.
The original receipt/logs remain in `attempts/001`; a new attempt rechecks validity
and reuses partial successes. No compiler/test failure is automatically retried.
If a worker dies after recording a failed Nix command, that failure remains
non-retryable even without a final worker receipt. A surviving owned Nix client is
reported as `cleanup-required`; retry is refused and `latest stop` can signal the
client using its recorded process identity. Status distinguishes `supervisorActive`
and `clientActive`; `workerActive` covers either kind of live owned work.

A launch intent without an acknowledged process, systemd invocation or worker
receipt is ambiguous. It fails closed and requires manual resolution; absence of
an observed PID or unit is insufficient to authorize another attempt. `stop`
records a durable marker so a delayed worker cannot issue commands, but never
signals an unbound unit or unknown PID. It does not claim that an ambiguous launch
has been cleaned up. Workers bind to their own attempt under the worker lock;
delayed or duplicate workers cannot adopt another attempt or repeat completed work.
A stopped run never resumes. A second interruption remains terminal for investigation.
Launch and worker locks prevent duplicate work; explicit stop validates the owned
unit invocation/cgroup or uses a validated PID/startTicks/boot identity and pidfd.
An unavailable supervisor is an observation error, not proof that a build failed.
If a worker is killed before it can write its finally receipt, status reports an
honest infrastructure interruption from the inactive unit and absent worker lock;
it does not invent a client return code or signal sender.

Run evidence uses versioned `tvp.latest-*/v1` JSON: `subject.json`, `descriptor.json`,
`preflight.json`, sealed `bindings.json`, `host.json`, live `state.json`, per-attempt
`launch.json`, before-validity, command/client receipts and logs, roots and
`result.json`. The top-level result is the last terminal worker receipt, while
`state.json` and `status` describe any active retry. Terminal results carry scope
`full=false`, source identity, actual stage, command/return codes, signals,
verification and explicit `machineReady=false` / `mergeEligible=false`. A failed
command may leave its failing downstream derivation unknown; the exact request
and log are retained. `verify` performs a new read-only availability/link check
of a successful terminal run without rerunning builds or modifying its receipt.
For long-lived observers the copied `code/latest.py` can be invoked with the same
rooted interpreter recorded in `attempts/NNN/launch.json`.

The existing `start/status/wait/stop/verify`, full plans, representative verifier
and all catalogue/construction policies retain their interfaces. A full historical
run remains a separate explicit action. Hosted CI remains OFF until migration is
complete; this workflow does not activate or satisfy a protected full-suite gate.
