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
│       ├── default.nix
│       ├── build-2.7.nix
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
- **Every fork records why**, in a header comment: what forced it, and what it was copied
  from.
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
line_2_7 = {
  builder = ./build-2.7.nix;
  deps = {
    openssl = tvp.packages.openssl_1_1_1w;
    inherit (pkgs) readline zlib gdbm;
  };
};

versionTable = {
  "2.7.0" = line_2_7 // { sha256 = "sha256-jJmqk7…"; };
  "2.7.8" = line_2_7 // { sha256 = "sha256-wtq2PL…"; };
};
```

- **The table is explicit.** No computed "greatest start-version ≤ v" lookup — this is the
  file someone opens to find out what `2.7.0` actually is.
- **Dependencies are declared per line, not per patch.** Every 2.7.x shares one graph;
  stating it once is smaller *and* more readable than repeating it. A version that
  genuinely differs overrides at its own entry, so every version still resolves to a fully
  determinate graph.
- **Source URLs are derived from the version**, not stored per version.

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
