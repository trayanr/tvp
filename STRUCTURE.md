# Repository structure

How TVP is laid out and why, so a change lands where the next person expects to find it.

## The tree

```
bases/                        the ground packages are built on; `tvp.bases`
├── default.nix               named bases; canonical names immutable, aliases move
├── stdenv/                   TVP's vendored mkDerivation
└── tests/                    one shared suite, instantiated per base

lib/                          shared evaluation logic; the flake's `lib` output
├── versions.nix              version parsing, predicates, attribute naming
├── bases.nix                 mkBase and its assertions, mkBaseSuite
├── packages.nix              version table → package set, merging, alias checks
└── tests.nix                 mkTest / mkSuite / mkBatch

pkgs/
├── default.nix               index of categories
├── libraries/                openssl, zlib, libxml2, sqlite …
│   ├── default.nix           index of packages in this category
│   └── openssl/
│       ├── default.nix       definitions, index of version files, aliases
│       ├── 0.nix … 4.nix     releases, grouped by definition
│       └── build-1.1.1.nix   build procedure
├── runtimes/                 ruby, php, python, perl, node, jdk …
│   └── ruby/
│       ├── default.nix       definitions, index of version files, aliases
│       ├── 2.nix             releases; per major once one file outgrew ~500 lines
│       ├── 3.nix
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

## Definitions and releases

Version data is split in two. A **definition** is a whole build recipe; a **release** is a
version and its hash. Definitions live in the package's `default.nix`, releases in version
files beside it.

```nix
# pkgs/runtimes/ruby/default.nix
defs = {
  "2.7.0" = {
    builder = ./build-2.7.nix;
    base = tvp.bases.gcc13;
    deps = {
      openssl = tvp.packages.openssl_1_1_1w;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
      gdbm = pkgs.gdbm;
    };
  };
  …
};

versionTable = merge {
  "2" = mkTable (import ./2.nix { inherit defs; });
  "3" = mkTable (import ./3.nix { inherit defs; });
};
```

```nix
# pkgs/runtimes/ruby/3.nix
{ defs }:
[
  {
    def = defs."2.7.0";                    # 3.0 needs no recipe of its own
    releases = {
      "3.0.0" = "sha256-oT7RQaHBjrlnqsHjP01q1fIb4axUPDRODW/u7lSvjig=";
      …
    };
  }

  {
    def = defs."3.4.0";                    # one release; upstream shipped it oddly
    releases = {
      "3.4.0" = "sha256-BoyFI0QhdL00AOeG9KaVI1LIKxufYhD9F/tIIwhtM3k=";
    };
  }

  {
    def = defs."3.3.0";                    # and back again
    releases = { "3.4.1" = "sha256-PTheXSLTaLBkyBehPtjjzD9xp3BdftG654ATwzqnyH8="; … };
  }
]
```

Twenty-six definitions serve 340 releases. OpenSSL needs six for 221 versions.

### Rules

- **A definition is named for the version where it first appears** — a name, not a range.
  Definitions are *not* monotone in version: a deviation ends and later releases point back
  at the earlier definition. OpenSSL `0.9.8k` returns to `defs."0.9.6"` after the hardened
  run; Ruby `3.4.1` returns to `defs."3.3.0"` after `3.4.0`. That return is the fact worth
  seeing, and it is why a definition cannot claim a forward range the way a builder does.
- **A version that differs forks a definition; it never overrides one.** A release entry may
  hold only `def`, `sha256` and `status`; anything else fails to evaluate. Forking in full
  keeps definitions diffable against each other, exactly as forked builders are.
- **A block is a contiguous run of releases sharing everything but their hash.** Blocks are
  a list rather than an attrset so they stay in release order and one definition may appear
  in several.
- **A release is its hash**, or an attrset where there is more than a hash to state.
- **A status belongs to the block when the recipe causes it** — every Ruby 4.0 is degraded
  for the same reason — **and to the release when the release does**, as OpenSSL 3.0.4 is
  alone among its 64. Declaring both for one release is a contradiction, not a merge, and
  throws.
- **Every definition declares `base`.** There is no per-package default: a definition that
  silently landed on the wrong ground would be invisible, while a missing one fails to
  evaluate. `null` says the builder takes no stdenv because it delegates to a nixpkgs
  helper — a fact worth declaring, and an M9 worklist entry.
- **`deps` holds derivations; `opts` holds everything else.** `libDir`, `pbkdf2`, `yjit` and
  `hardeningDisable` are builder arguments but not dependencies, and `deps` is what the
  canonical-graph contract is written about. `checkDeps` throws on a non-derivation.
- **Nothing is supplied that is not named.** `mkVersions` calls the builder through
  `lib.makeOverridable` with an explicit `infra` set rather than `callPackage`, so an
  argument that is neither infrastructure nor version data fails to evaluate. `infra` is
  what a package still borrows from nixpkgs, and it shrinks to nothing at M9.
- **A version file receives `defs` and nothing else.** It cannot reach `pkgs` or
  `tvp.packages`, so a release cannot acquire a dependency its neighbours lack. That class
  of defect was real: two packages had versions silently using nixpkgs' dependency while
  their siblings pinned TVP's.
- **A changed *value* is a definition; a changed *procedure* is a builder.** Ruby 3.4.0 sets
  `libDir = "3.4.0+1"` because upstream shipped that tarball with `RUBY_PATCHLEVEL -1` —
  a definition, not a builder fork.
- **Source URLs are derived from the version**, not stored per release.
- **When a file passes ~500 lines it splits per major**, and a major that outgrows one file
  becomes a directory of minor lines, each level indexing the next explicitly. Split under
  observed pressure, never on predicted structure. Moving releases between files is
  provably free; prove it with `drvPath` rather than assuming.

### What this replaces

An earlier rule said every entry must state its whole graph, repetition and all, because
"an entry that inherits half its meaning from elsewhere" cannot answer what a version is.
The reasoning was right and the conclusion was too strong. A definition gives an entry
*all* of its meaning, not half, and an entry may not add to it — so nothing is inherited
piecemeal. What the old rule correctly forbade, and what is still forbidden, is an entry
that patches a shared base: no `line_2_7 // { … }`, and no computed
"greatest start-version ≤ v" lookup.

Measured on the catalogue, the old form spent 3194 lines to say what 1239 now say, and
roughly three quarters of those lines were exact duplicates of a neighbour.
## Package status

A version says what TVP claims about it, in the version table:

```nix
status = {
  level = "degraded";
  reason = "YJIT and ZJIT are disabled; upstream enables both by default.";
  needs = "rustc >= 1.85 — the JIT crate requires Rust edition 2024.";
};
```

| Level | Means |
|---|---|
| `ok` | built the way upstream builds it — the default, never written out |
| `degraded` | builds and passes its tests, but a documented capability is off |
| `broken` | does not build |

- **`degraded` is why this exists.** `ok` and `broken` announce themselves; a package that
  builds, installs and passes every test while quietly missing a feature does not.
- **Anything but `ok` must declare `reason` and `needs`**, enforced at evaluation. `needs`
  states what would clear the status, so it is also the worklist.
- **`broken` does not set `meta.broken`.** That would make Nix refuse to evaluate the
  attribute, failing `nix flake check` and hiding the version from the catalogue. A broken
  version stays addressable; it is exempt from `every-package-tested` and `testBatches`
  because there is no build to test.
- **`knownTestFailures = [ "rsa" ]`** drops named tests for one version, and is allowed only
  when the status is not `ok`. For a defect upstream shipped, keeping the test reddens CI
  forever and deleting it hides the defect from every other version.
- Status lives in `passthru`, so it never changes a derivation.

```sh
nix run .#status            # inventory, with reasons
nix run .#status -- --json  # same, for tooling
```

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

## Bases

A definition declares two different things: the **graph** it depends on (`deps`) and the
**ground** it is built on (`base`). Bases live in `bases/default.nix` and are reached from
a version table as `tvp.bases`, exactly as packages are reached as `tvp.packages`.

The seam is `stdenv`, and it already existed. Every builder takes `stdenv` as an argument
and calls `stdenv.mkDerivation`; a base is simply TVP supplying that argument instead of
letting `callPackage` fill it from nixpkgs.

```nix
# pkgs/libraries/openssl/default.nix — one of six definitions serving 221 releases
"1.1.0" = {
  builder = ./build-1.1.1.nix;
  base = tvp.bases.gcc13;                       # named, never inherited silently
  deps = { perl = tvp.packages.perl_5_28_3; };  # derivations — the canonical graph
  opts = { pbkdf2 = false; };                   # build options
};
```

- **No builder mentions a base.** Swapping one is a substitution rather than an edit.
- **A base is what a build gets without asking.** The test is mechanical: *if a package can
  name it, it should name it; the base holds only what cannot be named.* That closes the
  list at 17 — the 14 in stdenv's `initialPath` plus gcc, binutils and glibc — and stops it
  growing with the catalogue. perl, m4, pkg-config and rustc are all nameable, so they are
  version data, never base content.
- **Only the toolchain is era-pinned.** gcc, glibc and binutils reach the artifact; the
  floor (`sed`, `grep`, `make`, `tar`, …) runs during the build and vanishes, so it merely
  has to work. A base is not a collection of era-blessed package versions.
- **A base is a record** (`{ name; stdenv; }`), not a bare stdenv, so it can carry what a
  toolchain pin cannot express — beginning with `builtBy`, since old compilers cannot be
  built by new ones and a base's chain is part of its identity.
- **Canonical base names are immutable; aliases move**, and the name is *asserted*. A base
  is named for its compiler (`gcc13`, `gcc9`), and `mkBase` fails to evaluate if the stdenv
  carries a different one — so a nixpkgs bump cannot silently redefine a base name.
- **`builtBy` is required**, naming the base that compiled this one. Old compilers cannot be
  built by new ones, so bases form a chain. `null` means nixpkgs bootstrapped it.
- **Bases follow the package patterns**: `mkBase` in `lib/bases.nix` beside `mkVersions`,
  one shared suite in `bases/tests/` instantiated per base, and `checks.every-base-tested`
  mirroring `every-package-tested`. A base test is built by that base's own stdenv, or it
  would test the default substrate whichever base it claimed to cover.
- **Every definition declares `base`** — there is no per-package default. A definition that
  silently landed on the wrong ground would be invisible; a missing one fails to evaluate.
- **`base = null` declares a definition is not on a base at all**, because its builder
  delegates to a nixpkgs helper rather than calling `stdenv.mkDerivation`. Declared, never
  inferred — bundler is the only one.
- **`passthru.tvp.base` records the name**, not the record.

`bases/` is derivation-affecting in full: every package on a base rebuilds when that base
changes. That is dependencies working correctly, and the blast radius is one base rather
than the repo — the same containment `build-VERSION.nix` gives a build procedure. It is
also why there is still no `mkTvpDerivation`: a customised `mkDerivation` inside a named,
versioned base is scoped and forkable; a single global wrapper is not.

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

**Add a version of an existing package** — add one line to the block whose definition it
uses: `"3.6.4" = "sha256-…";`. Adding a version rebuilds nothing that already exists.

**Add a version that needs different dependencies or options** — copy the current
definition in `default.nix` to one named for that version, change it there, and open a new
block pointing at it. If later versions go back to the old recipe, open another block
naming the old definition; that return is a fact, not a duplicate.

**Add a version that needs a different build procedure** — copy the current builder to
`build-<that version>.nix`, change it there, record in the header what forced the fork and
the range it serves, and point a new definition at it. Add a test covering what you fixed:
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
