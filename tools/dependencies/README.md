`nix run .#dependencies` still reports declared selector choices. Its schema 1,
filters, comparison and default text are unchanged.

Use `nix run .#dependencies -- --recursive --root packages.json-c_0_19` to
inventory the intended recipe's transitive native build inputs. Use
`--recursive --list-roots` for validated labels and groups. Repeat `--root` to
combine roots, for example `--root @tools --root @bases`. Without `--root`,
recursive mode selects all buildable canonical package registrations
(`@canonical`), including degraded packages. Variants, construction, bases,
compositions and repository checks are explicit groups. Declared-broken roots
retain their status/reason in the catalogue and JSON exclusions; requesting one
returns a partial report without evaluating its recipe or claiming a build.
Support inputs reached from any root remain in the graph even when unregistered.

`--recursive --json` adds a versioned `recursive` section to the ordinary
inventory. Nodes use intended `.drv` paths, with all root labels preserved,
selected output names, deferred output metadata, builder/system and source
inputs. A `.drv` referenced only by `inputs.srcs` remains a source artifact.
`--why /nix/store/…` explains a reachable derivation or source through a
deterministic shortest chain from a selected root. JSON's `witnesses` stores
parent pointers for one such chain per node; it does not enumerate every path
or every root reaching a shared node. `--details` lists derivation identities.

Recursive mode rejects `--compare`, `--kind`, `--scope`, `--family` and
`--exceptions`; those flags describe declaration choices, not native graph
selection. `--root`, `--why` and `--list-roots` require `--recursive`.
`--list-roots` cannot be combined with `--root` or `--why`.

The flake is snapshotted once. Both exports evaluate from that immutable source
with IFD disabled, offline and without lock writes. One batched host Nix
`derivation show --recursive --stdin` reads locally instantiated recipes;
outputs are never built or substituted by traversal. Protocol scope is Nix
2.34's version 4 derivation JSON. Unknown versions, unavailable recipes,
missing nodes, cycles, malformed metadata or unresolved dynamic input selectors
produce diagnostics, a partial state and exit 1. Unknown static CA output paths
remain unresolved rather than fabricated. Unknown origin alone is valid and
can occur in a complete graph. No full-mode truncation is applied.

Registrations distinguish TVP definitions, substrate output controls and two
explicitly matched pinned Nixpkgs tool attributes (jq and shellcheck-minimal).
Output registrations annotate source/binary/mixed evidence without identifying
a different recipe as canonical. Unregistered nodes remain unclassified: names,
missing selector tags, installed-output derivers and signature issuers do not
establish origin. Native edges prove reachability, not which hooks executed or
which compatibility branches are unused. Evaluation-time libraries and external
host interfaces need not appear. This inventory supplies evidence for later
architecture work; it makes no independence or runtime-closure claim.
