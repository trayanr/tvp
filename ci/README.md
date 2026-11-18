# Local builder and GitHub CI

The [CI architecture](ARCHITECTURE.md) defines the queue, trust boundaries, reporting
and NAS/cache plan. GitHub is the public PR/status surface; the local PC runs Buildbot
and TVP's focused smoke checks. The PC connects outward to GitHub; there is no public
listener, webhook, port forwarding or discovery requirement.

These files are for TVP maintainers. Using TVP packages does not install or start CI
services. Buildbot dependencies are loaded only through `ci/buildbot/shell.nix`.
Keep deployed configuration, credentials, NAS mounts and host setup scripts outside
the repository. The service files and `config.example.json` are templates.

## Testing scope

Default CI runs the installed checks in [tests/smoke.nix](../tests/smoke.nix),
following [TESTING.md](../TESTING.md). It includes every declared compatible
PHP/extension pair, with two small installed checks per pair. Four full compiler
bases, Perl, Ruby, Redis and FreeTDS have their own smoke checks. Use
`nix eval --json .#php.metadata` to see the current extension matrix counts.
The PHP compatibility matrix includes historical releases and may compile them
when their outputs are not cached. Other families retain representative checks.
CI does not run upstream regressions or every repository check.
The status is `tvp/smoke`; a smoke pass is never a full-catalogue pass.

The `smoke-catalogue` step shows compilation, finalization, assembly, suite and
test progress, along with active Nix builds, in `stdio`.
Its `flake-evaluation`, `preparation`, and `nix` logs stream the corresponding
worker files, including compiler output from Nix. Buildbot keeps these logs
with the completed build. The evidence upload retains those files alongside the
frozen plan, structured Nix events, and terminal test receipt.

For local iteration on one pair, use
`nix run .#test -- all --only php_8_5_12--redis_6_3_0`. The dedicated
`nix build .#php.extensionTestsAll` target selects only the PHP extension matrix;
the standard CI command includes it automatically alongside the other subjects.

Promote the reviewed harness and its matching tools revision together. The
required context is `tvp/smoke`, with up-to-date branches and administrator
enforcement. Repository settings allow squash merges only; `master` also
requires linear history. Changing the repository scripts alone does not update
a deployed controller.
The internal Buildbot builder identifier remains `tvp-full` to retain its history;
its active step and posted result explicitly describe smoke validation.

Full suites remain available only when explicitly requested:

```sh
nix run .#test -- start --full
# A selected full package suite can still contain expensive upstream tests:
nix run .#test -- start --full --only perl_5_30_3
```

## Migration closeout

The owner declared the builder/base and ordinary package-authoring migration
complete on 2026-11-16 and authorized committing/merging the final snapshot,
running validation, and resuming CI/NAS operations. The normal workflow below
applies after operational restoration, with the smoke policy above;
source migration completion does not waive runtime or hardening failures.
Actual service/protection observations belong in the deployment closeout receipts.

The following temporary exception is retained as historical execution policy.
It does not authorize future merges without the normal checks.

## Temporary migration workflow (historical)

The former `tvp/full` restoration target below records that earlier policy; the
current smoke policy above supersedes its required-context choice.

Owner-approved on 2026-11-14: keep CI execution and NAS/cache synchronization off
until the owner declares the builder/base and package-authoring migration complete.
Iterate on Tower with scoped local validation and reuse its existing Nix store.
Do not copy iteration outputs to or from the NAS or publish a synthetic passing
`tvp/full` status.

The required `tvp/full` merge check on `master` is suspended for this migration
period; all other branch protections stay unchanged. Baseline and follow-up merges
retain their recorded validation scope, known failures and hardening/historical
holds. A merge does not establish full-catalogue qualification.

Migration closeout restored CI/NAS operations and the strict `tvp/smoke`
requirement. The historical `tvp/full` target does not override the current
installed-result testing policy.

## Normal developer workflow

This is the workflow after the temporary migration exception ends.

Every open PR from this repository is tested automatically, including drafts
and stacked PRs targeting another repository branch. No label is required.
The branch must contain the **current** target tip: rebase or merge that target
into it before testing. CI tests the exact PR head and never constructs a merge
commit. A behind or diverged branch gets a pending `tvp/smoke` instruction
without a build. New commits and target updates are polled automatically.
Commits to `master` also run the standard installed-result selection. The worker
reuses its local outputs and configured signed NAS cache. Fork PRs remain outside
this trusted worker pool.

Use squash merge after the exact head passes. Require `tvp/smoke` and an up-to-date
branch in GitHub's merge protection. After another PR lands, update remaining branches
and wait for their new heads to pass before squash merging them. A target advance
after admission also stops a queued PR before Nix evaluation; update it and requeue.

On GitHub, inspect the `tvp/smoke` status for counts and failing versions. The local
Buildbot UI provides the queue, Rebuild action and complete failure logs. Buildbot binds
to localhost; a host-managed reverse proxy or SSH tunnel can provide private access.

## Reusing workstation builds

The private deployment has a separate Tower-to-NAS publisher. A plain `nix build`
on Tower stays local. Register an explicitly selected frozen terminal runner run
with the installed cache operator, then verify its publication:

```sh
tvp-cache-lifecycle register NAME /absolute/frozen/run --publish
tvp-cache-lifecycle ready NAME
```

Partial runs retain `full=false`. Declare the valid construction and compiler
outputs needed by the candidate among the run's owned roots: a runtime closure can
omit build-time bootstrap dependencies. The worker's Nix configuration supplies
the cache URI and trusted public keys. The required `tvp/smoke` check remains independent of cache publication.

Cancel superseded requests through the authenticated operator interface. A push
alone leaves older queued and running requests intact; polling schedules the new
head independently.
Host services, signing credentials, deployment addresses and retention records are
managed outside this repository.

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

The controller runs as the builder's administrator account, `server`, in its systemd
user manager. The worker remains a separate unprivileged `tvp-worker` Unix account
and system service. Do not add the worker to the administrator's groups, NAS write
groups or Nix's `trusted-users`.

One-time root setup creates `/srv/tvp-ci`, owned by `server`, and installs the worker
system unit. Put clean, reviewed revisions in `/srv/tvp-ci/releases/FULL_SHA`; keep
each release unchanged after promotion. The administrator manages the
`/srv/tvp-ci/current` symlink to the active release. The worker can read the source
tree but cannot modify it. Never point `current` at a candidate PR checkout. This
shared path also avoids granting the worker access through the administrator's home.

Create `~/.local/state/tvp-ci/controller` under the administrator's account and
`/var/lib/tvp-worker` under the worker's account, both mode `0700`. The controller's
configuration and secrets stay in its private state directory. Provision these files:

| File | Purpose |
| --- | --- |
| `secrets/github-token` | GitHub API credential for this repository only |
| `secrets/operator-password` | Local UI account `operator` |
| `secrets/worker-password` | Controller side of worker authentication |
| `config.json` | Copy of `buildbot/config.example.json` with real local paths and CI revision |

The initial GitHub credential needs repository metadata, contents and PR read access,
and commit-status write access. It needs no Actions, comment, administration or code
write permission. Keep credentials in the controller's private secrets directory,
readable only by the administrator account. Do not commit them or pass them as
command-line arguments. Set `secrets_directory` in `config.json` to the absolute
path of this private secrets directory.

Set `controller_revision` to the reviewed **full commit SHA containing this CI code**.
Leave `github_enabled` false during setup: the dashboard and worker can start without
polling GitHub or posting statuses. Enable it after the repository has the test-plan
interface and the controller has its GitHub credential.
The worker resolves its trusted test-runner executable from that revision. Copy the
worker authentication value into `/var/lib/tvp-worker/worker-password`, readable only by
the worker. The worker receives no GitHub or operator credential.

For a local deployment before the CI commit is pushed, `tools_ref` may instead point
to the deployed release with a NAR hash, for example
`path:/srv/tvp-ci/releases/FULL_SHA?narHash=sha256-...`. The hash pins the exact files;
both accounts must be able to read that release.

In the pinned CI shell, under the controller account:

```sh
buildbot create-master "$HOME/.local/state/tvp-ci/controller"
cp /srv/tvp-ci/current/ci/buildbot/master.cfg "$HOME/.local/state/tvp-ci/controller/master.cfg"
export TVP_CI_SOURCE=/srv/tvp-ci/current
export TVP_CI_CONFIG="$HOME/.local/state/tvp-ci/controller/config.json"
buildbot checkconfig "$HOME/.local/state/tvp-ci/controller"
```

For an existing deployment, stop the old controller before copying its entire state
directory, including its database, poller state, history, artifacts and secrets, into
the new private controller directory. Give the administrator ownership and update the
configuration paths. Preserve the old copy until the migrated history is verified;
do not run `create-master` over the migrated state. Retain `/var/lib/tvp-worker`,
its existing runs and their Nix GC roots. Disable the old system controller unit so
it cannot compete for the same ports. This migration keeps the Nix store, cache
configuration, publisher state and NAS contents in place.

Install `buildbot/tvp-controller.service` as
`~/.config/systemd/user/tvp-controller.service` for `server`. Root must enable
lingering once with `loginctl enable-linger server`, so the controller starts at boot
and continues after SSH logout. Install `buildbot/tvp-worker.service` in
`/etc/systemd/system/` and enable it as a system service. It connects to the controller
over loopback and retries when the controller is unavailable; it has no dependency
on a system controller unit. Review the Nix executable path against the actual host.
`worker.tac` reads its password file directly, avoiding a password in process arguments.

Root also installs `buildbot/tvp-worker.sudoers` as
`/etc/sudoers.d/tvp-worker` (mode `0440`), validating it with `visudo -cf`. This grants
only `server` passwordless access to four exact `/usr/bin/systemctl` commands for
`tvp-worker.service`: start, stop, restart and reload. It grants no unit editing,
unit enablement or access to other system units. Adapt the account name if the
builder uses another administrator. This works with Server’s older polkit version;
it does not require broad systemd permissions. After this bootstrap, ordinary
release promotion, controller configuration and service restarts run as `server`.
No services or authorization rules are installed by this repository automatically.

The one-time bootstrap can install a `tvp-ci` shortcut in `/usr/local/bin`:

```sh
#!/bin/sh
exec /usr/bin/python3 /srv/tvp-ci/current/ci/control.py "$@"
```

Routine operations run from the administrator account without sudo:

```sh
tvp-ci status
tvp-ci cancel BUILD_ID
tvp-ci restart-controller
tvp-ci restart-worker
```

The control command reads the private local operator credential itself; it does
not require typing it for each cancellation. Worker restart uses the exact
passwordless command internally (`sudo -n`); controller operations need no sudo. Service restart permissions do not
grant the worker access to controller credentials.

Visit `http://localhost:8010/` at the builder, or configure a reverse proxy on its LAN
address. Keep proxy and firewall configuration on the host and set `dashboard_url` in
the controller's private `config.json` to the address users visit. Control operations
require the operator login. After the first real GitHub status has appeared,
`tvp/smoke` can be made a required branch check. Repository settings are not changed by
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
systemctl --user status tvp-controller.service
journalctl --user -u tvp-controller.service -f
journalctl -u tvp-worker.service -f
```

As the administrator, manage the user controller and isolated system worker without
sudo:

```sh
systemctl --user daemon-reload
systemctl --user enable --now tvp-controller.service
systemctl --user restart tvp-controller.service
tvp-ci restart-worker
```

Promote reviewed release copies and update `current` as the administrator, then restart
the controller and worker when the current validation has finished or been deliberately
stopped. Keep the controller revision and pinned tools reference aligned with the
promoted code. The host-managed Nix daemon still supplies the worker's signed cache
URI and public keys; worker access to controller secrets or NAS write credentials is
not needed.

Each Buildbot build has a unique `runs/BUILD_NUMBER` worker directory and controller
`artifacts/BUILD_NUMBER` evidence directory. Evidence includes the source identities,
producer graphs, frozen validation plan, final status and available full failure logs.
The Buildbot smoke-catalogue log also includes failure logs and progress counts.
Inside that worker run, the frozen runner can inspect ongoing validation:

```sh
RUNNER status --run EXACT_RUN_PATH --json
```

The exact paths are in `evidence/launch.json`. Rebuild in the authenticated UI to retry
an unchanged commit; push a fix to automatically queue a new revision. The default queue
does not cancel running work or collapse different commits. Closing a PR prevents
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

## Foreground smoke entry point

The CLI reads runs on the machine where it is invoked. `status` follows `latest` in
the chosen state directory; it does not query the builder's queue or search other state
directories. Use the Buildbot dashboard for server CI builds.

For trusted local development, independently of Buildbot:

```sh
nix run .#test -- all
# Include CI's graph and flake evaluation first:
bash ci/validate.sh .tvp-tests/ci
nix run .#test -- status --state-dir .tvp-tests/ci --json
```

`all` waits for its exact frozen run and returns success or failure. It uses the
standard focused smoke plan, inherits Nix's job/core settings, reuses valid cached
outputs, and retains logs, result roots and terminal `result.json` in the printed
run directory. Buildbot invokes this same command through its pinned trusted tools
revision and adds head validation, graph comparison and evidence reporting.
