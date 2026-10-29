# Local builder and GitHub CI

The [CI architecture](ARCHITECTURE.md) defines the queue, trust boundaries, reporting
and NAS/cache plan. GitHub is the public PR/status surface; the local PC runs Buildbot
and TVP's full validation. The PC connects outward to GitHub; there is no public
listener, webhook, port forwarding or discovery requirement.

These files are for TVP maintainers. Using TVP packages does not install or start CI
services. Buildbot dependencies are loaded only through `ci/buildbot/shell.nix`.
Keep deployed configuration, credentials, NAS mounts and host setup scripts outside
the repository. The service files and `config.example.json` are templates.

## Developer workflow

Open a non-draft expansion PR from a branch in this repository, targeting master, then
add `ci:build`. The branch must already contain the **current** target tip: rebase or
merge master into it before testing. CI tests that exact PR head and never constructs
a merge commit. A behind or diverged branch gets a pending `tvp/full` instruction
without a full build. New commits requeue automatically while the label remains. Both PRs and
master run the full catalogue. Existing local Nix outputs are reused; there is no TVP
binary-cache service yet. Fork PRs require a later disposable VM worker pool.

Use squash merge after the exact head passes. Require `tvp/full` and an up-to-date
branch in GitHub's merge protection. After another PR lands, update remaining branches
and wait for their new heads to pass before squash merging them. A target advance
after admission also stops a queued PR before Nix evaluation; update it and requeue.

On GitHub, inspect the `tvp/full` status for counts and failing versions. The local
Buildbot UI provides the queue, Rebuild action and complete failure logs. Buildbot binds
to localhost; a host-managed reverse proxy or SSH tunnel can provide private access.

## Check the CI configuration locally

From this checkout:

```sh
NIX_BUILD_SHELL="$(command -v bash)" nix-shell ci/buildbot/shell.nix
python3 -m unittest discover -s ci/buildbot/tests -p test_policy.py
python3 -m unittest discover -s ci/buildbot/tests -p test_job.py
python3 -m unittest discover -s ci/buildbot/tests -p test_configuration.py
python3 -m twisted.trial --temp-directory=/tmp/tvp-ci-trial ci/buildbot/tests/test_changes.py
```

The shell uses Buildbot and plugins from TVP's locked Nixpkgs input. Tests do not call
GitHub or start package builds. They cover admission, pagination, exact SHA tracking,
restart/failure delivery, status handling and frozen-run validation.

Nix itself comes from the host installation. The service units put its managed profile
on PATH, so host Nix upgrades also apply to CI. Each run records the Nix version used.
CI evaluation and build commands enable `--show-trace`; failures retain the full Nix
trace in the build logs.

To check startup against a fresh store, run this in the CI shell:

```sh
python3 ci/buildbot/tests/evaluation.py --evidence .tvp-tests/evaluation
```

This copies the locked flake inputs into an isolated local store, then evaluates the
producer graph, flake checks and full test plan. It builds no packages. Choose a new
evidence directory on each run so existing store paths cannot hide evaluation errors.

A separate integration smoke test validates a master checkout with a fresh generated
input. It rejects outdated and diverging PR histories before Nix, then validates the
exact head after an explicit author merge of the target. Master and updated PR execute
a tiny frozen plan with Nix. It does not contact GitHub;
Nix may fetch dependencies for the already pinned Nixpkgs input:

```sh
nix run .#test -- --help > /dev/null
python3 ci/buildbot/tests/smoke.py --runner "$(nix eval --raw .#apps.x86_64-linux.test.program)"
```

The cancellation test starts an isolated controller and worker with a tiny Nix plan.
It checks queued cancellation, running stops, forced termination and stops during
startup, including reuse of completed outputs:

```sh
python3 ci/buildbot/tests/cancellation.py --runner "$(nix eval --raw .#apps.x86_64-linux.test.program)"
```

## Prepare the builder at its console

The current target is `x86_64-linux`; an existing Linux installation can be used.
Run `bash ci/builder-preflight.sh` and install Nix using the
[Nix installation guide](https://nix.dev/install-nix). Enable `nix-command`, `flakes`
and build sandboxing. Keep `/nix`, build scratch and controller state on local SSD.
The NAS is not needed for initial operation.

Create separate `tvp-controller` and `tvp-worker` service users, neither an administrator
nor a Nix trusted user. Put a clean checkout of the reviewed CI revision at `/opt/tvp-ci`,
owned by an administrator and not writable by either service user. Keep its Git checkout
at that revision; do not point the controller at an expansion PR checkout.

Create private state directories `/var/lib/tvp-controller` and `/var/lib/tvp-worker`,
owned by their respective users, mode `0700`. Provision the controller files:

| File | Purpose |
| --- | --- |
| `secrets/github-token` | GitHub API credential for this repository only |
| `secrets/operator-password` | Local UI account `operator` |
| `secrets/worker-password` | Controller side of worker authentication |
| `config.json` | Copy of `buildbot/config.example.json` with real local paths and CI revision |

The initial GitHub credential needs repository metadata, contents and PR read access,
and commit-status write access. It needs no Actions, comment, administration or code
write permission. Keep credentials in the controller's private secrets directory,
readable only by its account. Do not commit them or pass them as command-line arguments.

Set `controller_revision` to the reviewed **full commit SHA containing this CI code**.
Leave `github_enabled` false during setup: the dashboard and worker can start without
polling GitHub or posting statuses. Enable it after the repository has the test-plan
interface and the controller has its GitHub credential.
The worker resolves its trusted test-runner executable from that revision. Copy the
worker authentication value into `/var/lib/tvp-worker/worker-password`, readable only by
the worker. The worker receives no GitHub or operator credential.

For a local deployment before the CI commit is pushed, `tools_ref` may instead point
to the deployed source with a NAR hash, for example `path:/opt/tvp-ci?narHash=sha256-...`.
The hash pins the exact files; both service accounts must be able to read that checkout.

In the pinned CI shell, under the controller account:

```sh
buildbot create-master /var/lib/tvp-controller
cp /opt/tvp-ci/ci/buildbot/master.cfg /var/lib/tvp-controller/master.cfg
export TVP_CI_SOURCE=/opt/tvp-ci
export TVP_CI_CONFIG=/var/lib/tvp-controller/config.json
buildbot checkconfig /var/lib/tvp-controller
```

The service templates in `buildbot/tvp-controller.service` and
`buildbot/tvp-worker.service` are for the same PC and loopback-only communication.
Review the Nix executable path against the actual installation, install the units only
when ready, then enable them. `worker.tac` reads its password file directly, avoiding a
password in process arguments. Run the worker as its own account, not the controller.
No services are installed by the files in this repository.

Visit `http://localhost:8010/` at the builder, or configure a reverse proxy on its LAN
address. Keep proxy and firewall configuration on the host and set `dashboard_url` in
the controller's private `config.json` to the address users visit. Control operations
require the operator login. After the first real GitHub status has appeared,
`tvp/full` can be made a required branch check. Repository settings are not changed by
this implementation.

## Graph changes

PR validation compares the immutable current target admitted by the poller with the
exact PR head. The worker rechecks that target before evaluating either graph.
The comparison reports added, changed and removed producers in the build log and saves
exact before/after identities in `evidence/graph-diff.json`. It is informational:
dependency updates and other graph changes continue into the full validation without
controller allowances. Review the diff alongside the test results before merging.

The comparison uses resolved producers, so it includes consumers whose dependency
selector moved even when their own definition files were not edited. It does not
classify the cause of a change. The standalone graph comparator remains strict by
default; CI uses its `--report-only` mode. Invalid graph data still fails validation.

## Inspect and operate

```sh
journalctl -u tvp-controller -u tvp-worker -f
```

Each Buildbot build has a unique `runs/BUILD_NUMBER` worker directory and controller
`artifacts/BUILD_NUMBER` evidence directory. Evidence includes the source identities,
producer graphs, frozen validation plan, final status and available full failure logs.
The Buildbot full-catalogue log also includes failure logs and progress counts.
Inside that worker run, the frozen runner can inspect ongoing validation:

```sh
RUNNER status --run EXACT_RUN_PATH --json
```

The exact paths are in `evidence/launch.json`. Rebuild in the authenticated UI to retry
an unchanged commit; push a fix to automatically queue a new revision. The default queue
does not cancel running work or collapse different commits. Removing a label prevents
future admissions but does not discard already queued requests.

**Cancel** removes a queued request. **Stop** interrupts a running validation,
including its detached Nix runner. Completed outputs stay in the Nix store and can
be reused by a later build. A killed worker command also cancels its runner.

For the first master build, use **Build commit** on the builder page and enter its full
40-character commit SHA. The same action can validate any reviewed commit in this
repository. It requires the operator login. The master poller starts watching from
the current revision; later pushes are queued automatically.

Keep the run's Nix GC roots until an explicit retention decision. Controller state
stays on SSD and can be backed up to the NAS. Archive completed evidence to the NAS
from the controller side; workers do not get NAS write credentials. No archival,
garbage collection, cache publishing or signing job is enabled in this version.

## Existing full-suite entry point

The CLI reads runs on the machine where it is invoked. `status` follows `latest` in
the chosen state directory; it does not query the builder's queue or search other state
directories. Use the Buildbot dashboard for server CI builds.

For trusted local development, independently of Buildbot:

```sh
bash ci/validate.sh .tvp-tests/ci
nix run .#test -- status --state-dir .tvp-tests/ci --json
```

This uses the existing frozen-plan runner, inherits Nix's job/core settings and retains
logs, result roots and terminal `ci-status.json`. The Buildbot harness adds pinned
head validation, trusted graph comparison and reporting around that same runner.
