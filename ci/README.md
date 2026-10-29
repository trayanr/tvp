# Local builder and GitHub CI

The [CI architecture](ARCHITECTURE.md) defines the queue, trust boundaries, reporting
and NAS/cache plan. GitHub is the public PR/status surface; the local PC runs Buildbot
and TVP's full validation. The PC connects outward to GitHub; there is no public
listener, webhook, port forwarding or discovery requirement.

## Developer workflow

Open a non-draft expansion PR from a branch in this repository, targeting master, then
add `ci:build`. New commits requeue automatically while the label remains. Both PRs and
master run the full catalogue. Existing local Nix outputs are reused; there is no TVP
binary-cache service yet. Fork PRs require a later disposable VM worker pool.

On GitHub, inspect the `tvp/full` status for counts and failing versions. The local
Buildbot UI provides the queue, Rebuild action and complete failure logs. It binds only
to localhost. See the architecture for optional private access from the workstation.

## Check the CI configuration locally

From this checkout:

```sh
nix-shell ci/buildbot/shell.nix
python3 -m unittest discover -s ci/buildbot/tests -p test_policy.py
python3 -m unittest discover -s ci/buildbot/tests -p test_job.py
python3 -m twisted.trial --temp-directory=/tmp/tvp-ci-trial ci/buildbot/tests/test_changes.py
```

The shell uses Buildbot and plugins from TVP's locked Nixpkgs input. Tests do not call
GitHub or start package builds. They cover admission, pagination, exact SHA tracking,
restart/failure delivery, status handling and frozen-run validation.

A separate integration smoke test creates two diverging local Git histories, forms a
real merge and executes a tiny full frozen plan with Nix. It does not contact GitHub;
Nix may fetch dependencies for the already pinned Nixpkgs input:

```sh
nix run .#test -- --help > /dev/null
python3 ci/buildbot/tests/smoke.py --runner "$(nix eval --raw .#apps.x86_64-linux.test.program)"
```

## Prepare the builder at its console

The current target is `x86_64-linux`; the existing Ubuntu installation can stay.
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
write permission. Keep it only in the controller's private secrets directory. For
interactive assisted deployment, supply credentials through the secret-input mechanism,
not chat, repository files or shell arguments.

Set `controller_revision` to the reviewed **full commit SHA containing this CI code**.
The worker resolves its trusted test-runner executable from that revision. Copy the
worker authentication value into `/var/lib/tvp-worker/worker-password`, readable only by
the worker. The worker receives no GitHub or operator credential.

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

Visit `http://localhost:8010/` at the builder. The UI is readable locally; control
operations require the operator login. After the first real GitHub status has appeared,
`tvp/full` can be made a required branch check. Repository settings are not changed by
this implementation.

## Reviewed changes to existing producers

Additions need no graph allowance. For an intentional producer change, review the graph
output and add exact names to the controller's private `config.json`, for example:

```json
{
  "graph_approvals": {
    "17:FULL_HEAD_SHA:FULL_BASE_SHA": ["packages.php_7_4_33"]
  }
}
```

Reload the reviewed controller configuration and rebuild that request. These approvals
are exact to both commits; a PR cannot edit its own allowance. Unused approvals and
removals still fail. This is separate from fixing a failed new historical version by
forking its definition/builder and pushing another commit.

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

Keep the run's Nix GC roots until an explicit retention decision. Controller state
stays on SSD and can be backed up to the NAS. Archive completed evidence to the NAS
from the controller side; workers do not get NAS write credentials. No archival,
garbage collection, cache publishing or signing job is enabled in this version.

## Existing full-suite entry point

For trusted local development, independently of Buildbot:

```sh
bash ci/validate.sh .tvp-tests/ci
nix run .#test -- status --state-dir .tvp-tests/ci --json
```

This uses the existing frozen-plan runner, inherits Nix's job/core settings and retains
logs, result roots and terminal `ci-status.json`. The Buildbot harness adds pinned
integration, trusted graph comparison and reporting around that same runner.
