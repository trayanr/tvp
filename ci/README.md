# Linux builder and CI handoff

The first builder will be an existing Linux PC on the LAN. Install Nix alongside its
current distribution; TVP does not require a NixOS host. The initial validated target
is `x86_64-linux`. The distribution, hostname/address and builder account still need
to be supplied before host setup; these files do not configure or contact a machine.

## Inventory and first validation

Run `bash ci/builder-preflight.sh` on the PC. It reads architecture, CPU/memory/disk,
selected Nix settings and KVM access. It does not change Nix settings, keys, services
or resource limits. Individual settings are queried to keep access tokens out of the
report. See the [Nix installation guide](https://nix.dev/install-nix) for installation
on an existing distribution. Enable `nix-command` and `flakes`, and use the build
sandbox. The builder owns its local working Nix store.

From a checkout of an exact trusted TVP commit:

```sh
bash ci/validate.sh
```

This evaluates the flake, starts the existing full-suite runner and waits for its
terminal result. It inherits the machine's Nix concurrency settings. The exit code
reflects validation success. Run directories contain the frozen source/plan, runner,
logs, result roots and final `ci-status.json`. Inspect a running build with:

```sh
nix run .#test -- status --state-dir .tvp-tests/ci --json
```

## Graph review before a build

Save the producer graph from the base checkout and compare it from the candidate
checkout:

```sh
nix run .#neutral -- --graph save /tmp/tvp-before.json
# Change to the candidate checkout.
nix run .#neutral -- --graph diff /tmp/tvp-before.json --json
```

The snapshot includes canonical packages, variants, bases/aliases, private components,
bootstrap stages, declared consumers and SDK compositions. Additions pass; removals,
unreviewed changes and unused allowances fail. A deliberate migration is named with
repeatable `--allow-change EXACT_NAME` arguments; the JSON retains its before/after
identities. Reviewers control allowances. `--out` supports verified transport-only
changes where the output is unchanged. CI should run the comparison implementation
from the trusted base revision when evaluating an untrusted candidate.

## Control plane and worker roles

Start with trusted-branch validation on the LAN PC. GitHub can provide public checks
and logs; a controller can request the exact commit from the builder. Outbound polling
from home avoids opening the home machine to incoming Internet connections. Native
Nix remote builds over LAN SSH are also available for trusted local development;
see the [Nix remote-build manual](https://nix.dev/manual/nix/latest/advanced-topics/distributed-builds.html).

Untrusted PR builds require disposable VM workers with no publisher credentials or
access to the home LAN. A repository-level self-hosted Actions runner on the PC is
not that boundary. See [GitHub's self-hosted runner guidance](https://docs.github.com/en/actions/reference/security/secure-use#hardening-for-self-hosted-runners).
Keep signing/publishing as a separate trusted role: consume a passing frozen run and
its exact output closure, then sign and copy to the archival cache. Workers do not
need the cache signing key. Published artifacts remain independent of working-store
garbage collection. Remote registration, service installation, repository CI settings
and cache publication are subsequent deployment work.
