# Repository structure

How TVP is laid out and why, so a change lands where the next person expects to find it.

## The tree

```
lib/                          shared evaluation logic; the flake's `lib` output
├── versions.nix              version parsing, predicates, attribute naming
├── packages.nix              version table → package set, merging, alias checks
└── tests.nix                 mkTest / mkSuite / mkBatch

pkgs/
├── default.nix               index of categories
├── libraries/                openssl, zlib, libxml2, sqlite …
│   ├── default.nix           index of packages in this category
│   └── openssl/
│       ├── default.nix       version → builder table, version data, aliases
│       └── build-1.1.1.nix   build procedure
├── runtimes/                 ruby, php, python, perl, node, jdk …
│   └── ruby/
│       ├── default.nix       index: merges the version files, aliases, tests
│       ├── 2.nix             version data, split per major once it outgrew one file
│       ├── 3/                a major that outgrew one file in turn
│       │   ├── default.nix   index of the minor lines
│       │   └── 0.nix … 4.nix
│       ├── 4.nix
│       ├── build-2.7.nix     build procedure; one file per start version
│       ├── build-3.1.nix
│       ├── build-3.2.nix
│       ├── build-3.3.nix
│       ├── build-4.0.nix
│       └── tests/            the package's own test suite
├── build-tools/              cmake, autoconf, bundler, m4, make …
└── compilers/                gcc, clang, rust …             (not yet populated)
```

Categories exist so kinds of package can be treated differently — different testing
models, different version-population policies — without changing what TVP is.

| Category | Patch versions are populated |
|---|---|
| `libraries/` | densely — each patch release is a different set of CVE fixes |
| `runtimes/` | latest per line, older on demand |
| `build-tools/` | sparsely, on demand |

The model can *express* any patch version; it does not have to *package* every one.

## Every level is an index

Each `default.nix` names the level below it, explicitly:

```
default.nix → pkgs/ → <category>/ → <package>/ → build-VERSION.nix
```

**Never directory-globbing.** The point of an index is that it can be read; a glob turns
"what is in TVP" into something you have to run Nix to answer.

Indexes merge with a duplicate-name check rather than `//`, because `//` resolves a clash
silently in favour of whichever set came last.

## Builders are named for the version they start at

`build-VERSION.nix` serves every version from `VERSION` until the next builder file.

```
build-2.0.nix      serves 2.0 … 2.2
build-2.3.nix      serves 2.3 … 2.7
build-3.0.nix      serves 3.0 …
```

The `build-` prefix keeps builders distinct from version data, which is also named by
version.

Rules:

- **A divergence creates a file, not a guard.** When a version needs the recipe changed,
  copy the current builder to a file named for that version and change it there.
- **Files stay guard-free.** A guard is permitted only when it is a single, obviously
  local line. Anything structural forks a file.
- **Every fork records why**, in a header comment: the upstream change that forced it, and
  the range it serves. Not what it was copied from — `diff` against the adjacent builder
  answers that exactly.
- **Keep forked files structurally identical** — same attribute order, same shape — so
  `diff build-2.0.nix build-2.3.nix` is meaningful.
- **Every meaningful dependency is a function argument.** That is the seam `.override`
  needs.
- **Fixed-point form** (`stdenv.mkDerivation (finalAttrs: …)`) so tests and overrides
  compose.

Why not per-major: across 254 Ruby versions the only build-affecting divergences are at
1.9, 2.0, 3.1, 3.2 and 4.0 — none of them a major boundary. Start-version files put the
split exactly where the change is.

### Why forking is safe

A guard that does *not* fire can still change a derivation. In `nixpkgs-ruby`, one commit
guarded by `docSupport` (default `false`) rebuilt **all 254 versions** to byte-identical
output, because the disabled branch left a stray newline in a multi-line string. Forked
files cannot do that to each other.

The cost is drift — a fix applied to one builder may also be needed in an older one. That
is what the shared test suite is for; see below.

## Version data lives in the package's `default.nix`

```nix
versionTable = {
  "2.7.0" = {
    builder = ./build-2.7.nix;
    sha256 = "sha256-jJmqk7…";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };

  "2.7.8" = {
    builder = ./build-2.7.nix;
    sha256 = "sha256-wtq2PL…";
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };
};
```

- **Every entry states its whole graph, even when that repeats.** No `line_2_7 // { … }`,
  no computed "greatest start-version ≤ v" lookup. This is the file someone opens to find
  out what `2.7.0` actually is, and an entry that inherits half its meaning from elsewhere
  does not answer that. The repetition is the price and it is worth paying.
- **Anything a version does differently is stated at that version.** Builder arguments have
  defaults for the usual case, and an entry overrides one where upstream disagrees — Ruby
  3.4.0 sets `libDir = "3.4.0+1"` because upstream shipped that tarball with
  `RUBY_PATCHLEVEL -1`. A changed *value* is version data; only a changed *procedure* forks
  a builder.
- **Source URLs are derived from the version**, not stored per version.
- **When the file passes ~500 lines it splits per major**, and a major that outgrows one
  file becomes a directory of minor lines — `3/0.nix`, `3/1.nix`. Each level's
  `default.nix` indexes the next explicitly. Moving entries between files is provably free;
  prove it with `drvPath` rather than assuming.

## Choosing dependency versions

> Take the latest version the upstream release itself declares compatible, read from
> upstream's own build configuration rather than inferred or copied from another distro.

Ruby 2.7 is the worked example. `ext/openssl/extconf.rb` states the bound, and it moves
mid-line:

| Ruby | Upstream OpenSSL constraint |
|---|---|
| 2.7.0 – 2.7.4 | `>= 1.0.1` |
| 2.7.5 – 2.7.8 | `>= 1.0.1 and < 3.0.0` |

TVP pins 1.1.1w for all nine — the latest release satisfying both.

The rule selects a pin **once**, when the version is added. The pin is then immutable:
"latest compatible" evaluated today and in five years give different answers, and a
canonical graph that changed meaning would break the guarantee that pinning a TVP revision
pins the whole universe. Moving a pin afterwards is a deliberate rebuild, not an update.

It is not a security claim. TVP does not backport fixes, and availability is not a
statement that something is safe to deploy.

**A changed constraint is not automatically a builder fork.** 2.7.5 tightened its OpenSSL
bound without changing how Ruby builds, so it is version data. Fork on a changed *recipe*,
not a changed *range*.

## Naming and aliases

- Canonical names are immutable: `ruby_2_7_0` never changes meaning.
- Aliases are separate and movable: `ruby_2_7`, `ruby_2`, `ruby`.
- Moving an alias must never redefine a historical package identity — an alias may not
  shadow a canonical name, and this is checked.
- Superseded versions are kept, not replaced. `openssl_1_1_1u` stays alongside `1.1.1w`;
  only the alias moves.

## Tests

Tests live inside the package directory, in `tests/`. A package directory is
self-contained: builders, version data, and the tests that prove them.

**One suite per package, shared by every version, never forked.** This is the opposite of
the builder rule, and deliberately so:

| | Builders | Tests |
|---|---|---|
| Divergence handled by | forking the file | a guard inside one file |
| Effect of an edit | contained to one era | global, by design |

Adding a test produces a new test derivation for **every** version — including versions
whose package derivation did not change. That new test runs against the old build and
fails where an old builder is missing something. Fork the tests and that stops working.

- **Guards select whole tests** (`// lib.optionalAttrs pred { … }`). A guard never edits a
  test body: an attrset guard can only add or omit, but a guard inside a string can
  perturb its neighbour.
- **Guard on the declared graph, never on a version number.** `gdbm` runs iff the package
  declares a `gdbm` dependency, not iff the version is below 3.1. A builder that drops a
  dependency then drops its test automatically, and the two can never disagree.
- **Test what a failed build would not tell you.** An extension whose `extconf.rb` fails is
  usually skipped rather than fatal, so the package still builds and still installs, just
  without that extension. Only a test that actually `require`s it notices.
- **Tests are attached centrally**, via a required `mkTests` builder argument supplied by
  `default.nix`. A forked builder that drops the argument fails to evaluate, so test
  coverage cannot be silently lost in a copy.
- **Tests assert, they do not merely exit 0.** `cmd > $out` passes for anything that exits
  cleanly with no output. `mkTest` requires an `expected` value.
- **Every declared dependency gets a test proving it is genuinely linked.** An untested
  dependency is where drift hides.
- Fixtures are referenced as individual file paths, not directory paths, so an unrelated
  file does not invalidate the test.

Test names are a CI contract, so CI never needs to know whether it is looking at Ruby 1.8
or PHP 5.6: `build`, `smoke`, `version`, `stdlib`, `openssl`, `compile`, `upstream`.

```sh
nix build .#testBatches.x86_64-linux.ruby_2_7_0     # one package's whole suite
nix build .#packages.x86_64-linux.ruby_2_7_0.tests.openssl
```

## `lib/`

Shared evaluation logic, exposed as the flake's `lib` output so changing it is a visible
compatibility event.

Entries are split by whether they can reach a derivation. This is a **diagnostic**, not
cost control — knowing that renaming an attribute is evaluation-only means that if 400
packages rebuild, something has leaked.

| Tier | Contains | An edit here |
|---|---|---|
| Evaluation-only | attribute names, alias maps, table expansion, test attachment | changes no `.drv` |
| Derivation-affecting | source-URL derivation, any shared build snippet | rebuilds everything using it |

The same helper can be either, depending on use: `majorMinor` building the attribute name
`ruby_2_7_0` is free; `majorMinor` building `…/pub/ruby/2.7/ruby-2.7.0.tar.gz` is inside
`src` and is not. Derivation-affecting entries say so in a comment.

**There is no `mkTvpDerivation`.** A shared wrapper around `stdenv.mkDerivation` is the
most tempting thing to put here, and it is exactly the shared builder that start-version
files exist to avoid — hidden one level up. Builders call `stdenv.mkDerivation` directly.

## `checks` vs `testBatches`

| Output | Holds |
|---|---|
| `checks` | repo-wide invariants only — the package set evaluates, formatting is clean |
| `testBatches` | one buildable handle per package's suite, so CI gets a work unit per job |

`checks` is deliberately small. Projecting thousands of test derivations into it would make
`nix flake check` mean "realize the entire repository", which is not what a developer wants
from that command.

## Files split when they get too big

Same principle as builders: split on observed pressure, never on predicted structure. Per
package, independently — a library with three versions keeps one file forever.

```
one default.nix                    →  split at ~500 lines
per major       2.nix  3.nix       →  still too big
majors become dirs, per minor      2/7.nix  2/6.nix
minors become dirs, per patch      2/7/0.nix
```

`default.nix` remains the index at every depth. Splitting is provably free: moving
definitions between files changes nothing computed, confirmable by comparing `drvPath`
before and after.

## Formatting is cache-invalidating

Reformatting Nix is **not** a no-op for derivations. A formatter run once changed
`ruby_2_7_0`'s derivation because a `preInstall` block contained tab-indented lines — Nix
strips a common *space* prefix from `''…''` strings but does not strip tabs the same way,
so the tabs were being shipped inside the shell script.

- Format with `nix fmt .` — the repo's pinned formatter, never a system one. A different
  nixfmt version formats differently.
- `checks.formatting` enforces it.
- Treat a formatting pass as a deliberate, batched event; never bundle it into an
  unrelated change.

## How to

**Add a version of an existing package** — add one entry to `versionTable` with its
`sha256`. If the recipe is unchanged, reuse the line's `deps`. Adding a version rebuilds
nothing that already exists.

**Add a version that needs a different recipe** — copy the current builder to
`build-<that version>.nix`, change it there, record in the header what forced the fork and
what it came from, and point the new table entry at it. Add a test covering what you fixed:
that is how the same gap gets detected in older builders.

**Add a package** — create `pkgs/<category>/<name>/` with a `default.nix` and one
`build-<earliest version>.nix`, then name it in the category's `default.nix`.

**Verify a refactor changed nothing**

```sh
nix eval .#packages.x86_64-linux.ruby_2_7_0.drvPath   # before and after
```

Moving files, splitting them, adding `passthru`, and reformatting are all *supposed* to be
derivation-neutral. The only way to know is to look.

**Note:** `git add` new files before evaluating. The flake source is the git tree, so an
untracked file is invisible to Nix.
