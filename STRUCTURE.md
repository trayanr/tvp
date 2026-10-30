# Repository structure

How TVP is laid out and why, so a change lands where the next person expects to find it.

## The tree

```
bases/                        the ground packages are built on; `tvp.bases`
├── default.nix               default and compatibility bases, pinned bootstrap inputs
├── stdenv/                   vendored build protocol and native constructor
├── wrappers/                 native compiler and linker wrappers
├── gcc13-owned/              explicit bootstrap stages and consumer graphs
│   └── tests/                checks explicitly attached by this base
└── tests/                    shared behavior and generic ownership checks

lib/                          shared evaluation logic; the flake's `lib` output
├── versions.nix              version parsing, predicates, attribute naming
├── bases.nix                 mkBase, base tests and runtime ownership audits
├── platforms.nix             native platform contract and architecture settings
├── packages.nix              version table → package set, merging, generated aliases
└── tests.nix                 mkTest / mkSuite / mkBatch

pkgs/
├── default.nix               index of categories
├── data/                     dated CA certificates and other build/runtime data
├── sdks/                     Flutter and independent Android SDK components
├── libraries/                openssl, zlib, libxml2, sqlite …
│   ├── default.nix           index of packages in this category
│   └── openssl/
│       ├── default.nix       definitions, index of version files
│       ├── 0.nix … 4.nix     releases, grouped by definition
│       └── build-1.1.1.nix   build procedure
├── runtimes/                 ruby, php, python, perl, node, jdk …
│   └── ruby/
│       ├── default.nix       definitions, index of version files
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
└── compilers/                LLVM/Clang and compiler distributions
```

Categories exist so kinds of package can be treated differently — different testing
models, different version-population policies — without changing what TVP is.

| Category | Patch versions are populated |
|---|---|
| `libraries/` | densely — each patch release is a different set of CVE fixes |
| `runtimes/` | latest per line, older on demand |
| `build-tools/` | sparsely, on demand |

The model can *express* any patch version; it does not have to *package* every one.

GNU archive recipes try the kernel.org GNU mirror and retain the original GNU server
as a fallback. The release hashes are unchanged: transport fallback preserves the exact
upstream artifacts and package outputs.

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
- **An optional *dependency* forks a builder; an optional *option* does not.** The test is
  which way the mistake fails: a forgotten dependency fails **silently** — the package
  builds, installs, exits 0 and quietly lacks a capability — while a forgotten option or
  patch fails **loudly**. A dependency argument defaulted to `null` is declared but not
  required, so a definition that forgets it still evaluates, which is exactly the silence
  that retiring `callPackage` was meant to end. Options and patches stay version data.
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
    base = tvp.bases.default;
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
  helper — a fact worth declaring rather than inferring.
- **`deps` holds derivations; `opts` holds everything else.** `libDir`, `pbkdf2`, `yjit` and
  `hardeningDisable` are builder arguments but not dependencies, and `deps` is what the
  canonical-graph contract is written about. `checkDeps` throws on a non-derivation.
- **A patch is version data, so it belongs to a definition and never forks a builder.**
  `patches = [ { file; reason; } ]`; both fields are required and `checkPatches` throws
  otherwise. The builder receives bare paths, so it stays a plain `mkDerivation` argument,
  while `passthru.tvp.patches` keeps the reasons for the catalogue. A builder holds
  *procedure*; patching a source is a fact about one run of releases, not a procedure. Patch
  files live in the package directory, under `patches/`.
- **Nothing is supplied that is not named.** `mkVersions` calls the builder through
  `lib.makeOverridable` with an explicit `infra` set rather than `callPackage`, so an
  argument that is neither infrastructure nor version data fails to evaluate. `infra` is
  what a package still borrows from nixpkgs, and it shrinks to nothing once TVP owns
  its own substrate.
- **A version file receives `defs` and nothing else.** It cannot reach `pkgs` or
  `tvp.packages`, so a release cannot acquire a dependency its neighbours lack. That class
  of defect was real: two packages had versions silently using nixpkgs' dependency while
  their siblings pinned TVP's.
- **A changed *value* is a definition; a changed *procedure* is a builder.** Ruby 3.4.0 sets
  `libDir = "3.4.0+1"` because upstream shipped that tarball with `RUBY_PATCHLEVEL -1` —
  a definition, not a builder fork.
- **Source URLs are derived from the version**, not stored per release.
- **A release that exists upstream but cannot be packaged is declared.** `unavailable` on the
  package's upstream metadata is a list of `{ versions; reason; }`, and the delta report
  subtracts it from what is missing and lists it separately. Fifteen OpenSSL releases have no
  surviving tarball anywhere; while they sat under "not packaged" the report could not say
  the true answer, which is nothing missing. A dead end that reads as work makes the whole
  report ignorable.
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

Choose a selector from upstream's declared compatibility, read from its build
configuration. Major, minor and exact selectors are all allowed:

```nix
tcl = tvp.packages.tcl_9;
tcl = tvp.packages.tcl_8_6;
tcl = tvp.packages.tcl_8_6_18;
```

Upstream constraints guide the initial choice; package and consumer tests confirm it.
Adding a newer release advances matching aliases and rebuilds their consumers. If a
consumer breaks, pin it to a verified working version and record why.
Other consumers can keep advancing. A dependency constraint belongs in the definition;
fork the builder only when the build procedure changes.

An exact package name fixes the upstream release. A pinned TVP commit fixes its source,
recipe, resolved dependencies and base. Build graphs may change between TVP commits.
Evaluation resolves aliases from the pinned catalogue; it does not query upstream.

## Naming and aliases

Two views of the canonical builds: `canonical` is exact and round-trips through
`attrName`; `packages` is what a user types, and there an alias wins. Both reference the
same derivations. Explicit alternative builds live separately under `variants`.

```
nix build .#openssl_1_1_1             → 1.1.1w   the newest 1.1.1x
nix build .#canonical.openssl_1_1_1   → 1.1.1    the 2018 release, exactly
```

- **Every tool and check reads `canonical`.** An alias winning inside a single namespace
  would take the shadowed release's only name and drop it out of `status`, `upstream`,
  `neutral`, `provenance` and `every-package-tested` — silently.
- Canonical names keep their upstream release: `ruby_2_7_0` always selects Ruby 2.7.0.
- Aliases are separate and movable: `ruby_2_7`, `ruby_2`, `ruby` — and the shortest name is
  the moving one, deliberately: take the latest while adding a version, let CI find the
  break, pin the exact release only when something forces it.
- `deps` may use aliases within upstream's compatibility constraints or exact releases
  for compatibility exceptions. The resolved graph is fixed by the TVP commit.
- Moving an alias must never change a canonical name's upstream release. Within
  `packages` an alias may shadow a canonical name — that is the ergonomic namespace
  doing its job — and the release stays reachable under `canonical`.
- Superseded versions are kept, not replaced. `openssl_1_1_1u` stays alongside `1.1.1w`;
  only the alias moves.
- **The cascade is generated, not written.** `mkAliases` builds every prefix of every
  version, pointing at the greatest one under it, so `.#ruby`, `.#ruby_3`, `.#ruby_3_4` and
  `.#ruby_3_4_10` all resolve and a package cannot silently lack a level. A package writes
  aliases only as `overrides`, for one that is a judgement rather than a maximum.
- **A trailing letter is a member label, not a level.** openssl spells 1.1.1w with no
  separator, so the numeric stem of a lettered component is a prefix too.
- **A `broken` version is never an alias target.** An alias means the latest *usable*
  version. Where every version of a line is broken the alias simply does not exist.
- **Alias names come from the version table, not from built packages.** Reading a package's
  `version` forces its `deps`, which reach back into the package set — deriving names from
  values is an infinite recursion.
- **Where upstream reuses a line's name for a release**, `packages` gives the line and
  `canonical` gives the release. OpenSSL 1.0.1 is both, and both are addressable.

## Named package variants

Named package builds live alongside canonical definitions in each package's
`default.nix`. `mkVariants` reuses that package's version table and builder, with an
explicit base and per-version dependency or option overrides. A profile cannot change
the source hash, builder or patches. The indexes merge these builds with duplicate-name
checks into `tvp.variants.<profile>.<exact-package-name>`; there are no generated aliases.
Variants carry `tvp.canonical = false` and their profile name in `tvp.variant`.

```nix
variants = tvpLib.packages.mkVariants (packageArgs // {
  inherit pkgs;
  profiles.ncurses64 = {
    base = tvp.bases.default;
    versions."8.3".deps.ncurses = tvp.packages.ncurses_6_4;
  };
});
```

```sh
nix build .#variants.ncurses64.readline_8_3 --no-link
nix build .#testBatches.x86_64-linux.variant-ncurses64-readline_8_3 --no-link
```

Variant evaluation and test attachment are checked alongside canonical packages.
Provenance counts their outputs as TVP-owned, while catalogue population and upstream
reports continue to use canonical versions. Bootstrap variants are constructed from
version data directly, so selecting one does not evaluate a canonical build that may
depend on the base being bootstrapped.

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
- **When a shared suite fails on an old version, guard — never lower the fixture.**
  Rewriting a test to the oldest common denominator costs every version that coverage to
  satisfy one. Declare the capability in the builder, guard the strong test on it, and
  keep a universal core underneath. Measure the boundary in the artifacts — grep the
  installed header, ask the built interpreter — never from release notes.
- **Test what a failed build would not tell you.** An extension whose `extconf.rb` fails is
  usually skipped rather than fatal, so the package still builds and still installs, just
  without that extension. Only a test that actually `require`s it notices.
- **Tests are attached centrally**, via a required `mkTests` builder argument supplied by
  `default.nix`. A forked builder that drops the argument fails to evaluate, so test
  coverage cannot be silently lost in a copy.
- **Packages own their test wiring.** A package can make its `mkTests` factory
  overridable with `lib.makeOverridable ({ pkgs }: package: …) { inherit pkgs; }`.
  `mkVersions` exposes that factory as `package.mkTests`, outside serializable TVP
  metadata. A port supplies `mkTests = package.mkTests.override { pkgs = testPkgs; };`
  alongside its new stdenv and dependencies; it does not import package test files
  from the base assembler.
- **Test-only tools can be exact definition pins.** PHP requires `testAutoconf` in
  `defs.deps` and exposes it under `tvp.testDeps` for its phpize consumer tests. It is
  absent from the interpreter's build inputs, so choosing a compatible test tool does
  not rebuild the interpreter. The suite still uses owned tools and the package's base.
- **A test context can run on a selected base.** `tvpLib.tests.withBase { inherit pkgs base; }`
  binds both the compiler context and `runCommand` to that base's stdenv. Merely replacing
  `pkgs.stdenv` leaves `pkgs.runCommand` closed over its original builder. New packages
  on the owned base use this context for their package suites.
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
  base = tvp.bases.gcc9;                        # a build forced this; `default` if not
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
  toolchain pin cannot express — beginning with `builtBy`, because the bootstrap parent
  and a base's chain are part of its identity.
- **A named base identifies an environment generation.** Its identity includes the exact
  compiler, libc, binutils, wrappers, hooks, floor tools and bootstrap inputs. Toolchain
  versions are asserted by `mkBase`; a replacement environment gets a new generation.
- **Use `base = tvp.bases.default` normally.** Advance the default to newer validated
  toolchains. Pin a package to an older base only when compatibility requires it, and
  record the reason. `passthru.tvp.base` records the resolved base name.
- **Public bases are the default and older bases with actual consumers.**
  Retire a superseded public base once its consumers have moved. Older TVP commits
  retain its definition; bootstrap recipes may still need it internally.
- **`builtBy` is required**, naming the reviewed parent used to construct the base.
  Construction inputs stay pinned and must not follow the default they are building.
  `null` means nixpkgs bootstrapped it.
- **Bases follow the package patterns**: `mkBase` in `lib/bases.nix` beside `mkVersions`,
  one shared suite in `bases/tests/` instantiated per base, and `checks.every-base-tested`
  mirroring `every-package-tested`. A base test is built by that base's own stdenv, or it
  would test the default substrate whichever base it claimed to cover.
- **Ownership declares only an ownership audit.** A base's `ownership` record supplies
  `roots` and `allowedRuntimePaths`; it implies no particular compiler, optional tool,
  component layout or consumer suite. Additional checks are attached explicitly through
  `mkExtraTests = base: …`. The runner merges shared, ownership and extra checks with
  duplicate-name rejection so an extra test cannot replace a shared assertion.
- **Every definition declares `base`** — there is no per-package default. A definition that
  silently landed on the wrong ground would be invisible; a missing one fails to evaluate.
- **`base = null` declares a definition is not on a base at all**, because its builder
  delegates to a nixpkgs helper rather than calling `stdenv.mkDerivation`. Declared, never
  inferred — bundler is the only one.
- **`passthru.tvp.base` records the name**, not the record.

Promote a new default through a full-catalogue PR. Report graph changes, run the full
validation and pin packages needing older environments before merging. Most packages
follow the default, so a promotion rebuilds most of the catalogue. We do not build
every package against every historical base.

GCC is also an ordinary catalogue package. Adding a GCC release does not promote it
into the default base or require a base for that release. The base assembler reuses the
package recipe with pinned construction inputs.

The current bootstrap boundary is explicit: `builtBy = null` bases still borrow their
compiler, binutils, glibc, wrappers, floor tools and setup script from the pinned nixpkgs
input. A TVP package built on one of them owns its recipe and named dependencies, not
that substrate. In particular, packaged raw binutils are not a replacement for the
bintools wrapper: the wrapper supplies library search paths, the dynamic interpreter
and runtime RPATH policy.

`gcc16-owned` is the default native x86_64 Linux base: GCC 16.2.0, binutils 2.42,
glibc 2.39 with Linux 6.9 headers, and 14 explicitly versioned floor tools. `default` and
`gcc16` both resolve to `gcc16-owned`. Its protocol-3 wrappers use the native GCC16
compiler built on the pinned `gcc13-owned-v3` parent, with explicit dependency variants
in `bases/gcc16-owned/inputs/`. The parent libc, binutils, floor, shell and fixup tool
are reused. `builtBy = "internal:gcc13-owned-v3"` records that construction boundary.
The GCC13-v3 compatibility selection remains for measured ACL 2.3.0/2.3.1
consumers: their nested zero-length string member trips GCC16 fortified copies.
Hardening and regression tests remain enabled; ACL 2.3.2/2.4.0 use GCC16. The borrowed
GCC13 seed, original owned generation and v2 remain internal. Their construction recipes live inside `bases/gcc13-owned/inputs/`;
there is no `tvp.bootstrap` API. Ordinary package definitions select the default
base and canonical dependencies. GCC 9 and GCC 4.9 compatibility bases remain.
Historical Gawk 3.x and Tcl through 8.6.8 explicitly select GNU89; GMP's older
compiler probes use GNU89 or GNU17, and GDBM 1.19–1.24, M4 1.4.19 and
pkg-config's bundled GLib use GNU17. These preserve source language assumptions
under GCC16's C23 default, following the [GCC14](https://gcc.gnu.org/gcc-14/porting_to.html)
and [GCC15](https://gcc.gnu.org/gcc-15/porting_to.html) porting guidance. Only
libffi 3.4.3/3.4.4 demote the undeclared-function diagnostic for the existing
`int open_temp_exec_file(void)`; [upstream fixed its declaration in 3.4.5](https://github.com/libffi/libffi/commit/ce077e5565366171aa1b4438749b0922fce887a4).
The sources, upstream checks and historical failure classifications are retained.

Canonical GCC, binutils and glibc follow the newest default; their bootstrap variants
retain the original producer graph. The RPATH hook's patchelf is pinned to the earlier
owned generation so selecting the default cannot introduce a dependency cycle.

The assembler is `bases/gcc13-owned/default.nix`. It reuses the versioned package recipes,
rebuilds their dependencies against the owned libc, and records each intermediate stage
in `bootstrap`. C-only bootstrap variants break the C++ runtime and shell cycles; the
final libraries and binutils restore the C++ bindings and gprofng. GCC retains its
three-stage bootstrap comparison. glibc starts from the upstream release, with declared
store-layout adaptations and no stable-branch fixes. Its libraries and tools are separate
outputs so the tools' scripts can use the resulting Bash and Perl without a libc/shell
dependency cycle. The rebinding procedure lives beside the glibc recipe in `tools.nix`;
the assembler calls `libc.mkTools { stdenv = floorStage; bash = floor.bash; inherit perl; }`.

The native wrappers live in `bases/wrappers/`. The new constructor, setup script and
default hooks live in `bases/stdenv/`; vendored protocol files retain their source revision
and license. The wrappers supply headers, startup objects, linker flags, interpreter,
RPATHs and hardening. Package setup hooks still belong to their packages.
The final bintools wrapper also binds gprofng's HTML program to its declared Perl,
including calls dispatched through the gprofng frontend; Perl is not added to the floor.

Platform facts live behind `tvp.lib.platforms` in `lib/platforms.nix`:

```nix
platform = tvp.lib.platforms.forStdenv stdenv;
# Alternatively: mkNative { buildPlatform = ...; hostPlatform = ...; targetPlatform = ...; }
```

The returned record preserves `buildPlatform` (where compilation runs), `hostPlatform`
(where the result runs) and `targetPlatform` (what a compiler generates code for). It also
supplies the libc-relative `dynamicLinker`, `linuxHeadersArch` and `libcLibdirAliases`.
Every base exposes this record as `base.platform`. The owned assembler passes it to its
environment constructor and wrappers; GCC, glibc and Linux headers resolve it from their
actual stdenv, including recipe overrides. The wrappers render the loader into their
script templates at evaluation time, preserving existing source hashes when the rendered
bytes do not change.

Only native `x86_64-unknown-linux-gnu` is currently supported. Cross compilation,
unsupported native systems and unsupported ABIs fail explicitly; the interface does not
claim ARM support. Adding platform facts does not extend a recipe's `meta.platforms`:
recipes keep their own tested support lists. Tool versions, bootstrap parents and glibc's
minimum kernel version remain choices of their base or recipe. The
`checks.native-platform-interface` contract checks rejection and base wiring.

An ordinary definition selects `base = tvp.bases.default`. When porting a package, its
dependency graph must be ported too: changing only its compiler can leave libraries on
the borrowed libc. `components` exposes the assembled toolchain, floor and supporting
libraries. The assembler's rebuilt variants are explicitly marked noncanonical and remain
separate from the ordinary compiler and libc packages in the catalogue.

Run the complete base validation with:

```sh
nix build .#testBatches.x86_64-linux.bootstrap-base-gcc13-owned --no-link
```

That batch includes the shared base suite, the assembled packages' suites, and zlib,
OpenSSL, libxml2, Tcl, SQLite and PHP consumer builds. The PHP suite also builds and loads
a module through `phpize` using the owned compiler. Runtime ownership checks compare the
base and consumer closures against exact lists of owned store outputs, so an installed
helper or an unused RPATH cannot silently retain a bootstrap package.
The component, consumer and gprofng checks are explicitly attached from
`bases/gcc13-owned/tests/`; other owned bases do not inherit those requirements.

`bases/gcc13-owned/tests/build-tools.nix` selects canonical owned tools, then declares
test-only binutils, three-stage GCC and glibc integration
builds using those inputs. Its rebuild helper is confined to these test consumers.
Reusable tool builds are defined in their package directories. Their suites and runtime
ownership audit are part of the complete base validation batch; the graph remains
exposed as `buildToolValidation` for inspection. Production dependencies never refer
to that validation record.

Canonical M4 1.4.21, Autoconf 2.73, pkg-config 0.29.2, Bison 3.8.2, Texinfo 7.1,
which 2.21 and minimal Python 3.12.5 follow `default`. The base implementation
constructs its pinned tool builds from the same version tables. Bootstrap GMP and
Autoconf explicitly retain bootstrap M4; bootstrap ncurses and binutils retain bootstrap
pkg-config. These dependencies keep construction independent of the base it
produces. Base migrations compare exactly which canonical derivations move, including
downstream consumers of a changed tool.

Ordinary tools select canonical Perl, Bash, ncurses and file as named dependencies;
they do not depend on the base assembler's private build stages. The locale program
comes from the selected base's libc tools, matching its ABI.
Canonical tool suites bind their builder and compiler to each package's actual stdenv.
The same test factories serve bootstrap variants without selecting the canonical base.
Minimal Python is a build interpreter with a declared list of disabled third-party
extension modules, not the full Python developer runtime. Its core standard library and
C embedding API are tested.

Automake 1.19, Libtool 2.6.2 and Flex 2.6.4 are new canonical packages built directly on
the default owned base. They reference canonical owned M4/Autoconf/Bison and Perl;
they do not move the existing versions to another base. Automake provides a setup hook
that adds declared packages' `share/aclocal` directories to `ACLOCAL_PATH`.

`bases/gcc13-owned/tests/autotools.nix` exposes these packages as `autotoolsValidation` and
attaches their suites and a runtime ownership audit to the full base batch. The suites
generate projects with `autoreconf`, build and install C/C++ shared libraries and an
executable, link a static library, load a module through libltdl, and compile scanners
with Flex and Bison. The tests themselves run on the owned stdenv.

```sh
nix build .#automake_1_19 .#libtool_2_6_2 .#flex_2_6_4 --no-link
nix build .#testBatches.x86_64-linux.bootstrap-base-gcc13-owned --no-link
```

The production bootstrap also selects TVP's tools: binutils uses bootstrap Bison,
Texinfo and pkg-config; GCC uses bootstrap Texinfo and which; glibc uses bootstrap Bison
and minimal Python. The internal construction profiles pin the borrowed seed
rather than following the default alias. `bootstrap.buildTools` records the helpers
actually selected by these production recipes. Their package suites and a check requiring
package-owned bootstrap variants are included in the complete base batch.

Bootstrap Texinfo binds its locale program to the parent base's glibc tools: using TVP's
new libc there would create a Texinfo/GCC/glibc cycle. Canonical Texinfo binds to the
owned libc tools. Runtime ownership does not remove these bootstrap dependencies: the
initial compiler still needs the parent's libc, shell, compiler and floor. Fetching and
generic evaluation infrastructure still use nixpkgs. The derivation constructor's
CMake/Meson flag helpers, metadata validation and conditional hooks are local files
under `bases/stdenv/`, copied from the same pinned revision as the build protocol.
Constructing the owned stdenv requires no nixpkgs source path. These import moves are
verified to preserve canonical, variant, base, bootstrap and consumer derivations.
An owned runtime base is not a claim that TVP is self-hosted or nixpkgs-free.
Native build-system packages ship their consumer setup hooks. Declaring
`nativeBuildInputs = [ tvp.packages.cmake_4_4_5 tvp.packages.ninja_1_13_2 ];`
selects CMake configuration and Ninja build/check/install phases. CMake alone uses
Make; `nativeBuildInputs = [ tvp.packages.meson_1_12_1 ];` selects Meson's phases
and its explicitly pinned Ninja, CMake, pkg-config and Python tools. The hooks search
declared library inputs, honor explicit phase overrides and expose flags through
`cmakeFlags`, `ninjaFlags`, and `mesonFlags` (with corresponding shell arrays).
Meson configures with downloads disabled; wrap sources must be declared or cached inputs.
The Python `python-build` profile includes TLS and archive modules; `python-minimal`
remains the separate bootstrap interpreter. These hooks currently implement native Linux
builds; cross compilation requires an explicit platform/toolchain design.

The complete construction generation, including Perl, Bash, compiler support libraries
and floor tools, is selected inside `bases/gcc13-owned/inputs/`. Package modules supply
uninstantiated recipe tables through the indexes' private `recipes` metadata. This lets
the base instantiate pinned inputs without evaluating canonical derivations that already
depend on it. The metadata and construction environments are not exported on `tvp`.
The assembler uses that generation rather than following canonical packages through
`default`.
`checks.bootstrap-independent` verifies its parent, package bases and dependency edges.
The switch preserves the bootstrap compiler, libraries and stages; the final linker
wrapper also exports `nix-support/dynamic-linker` and `orig-libc` for consumers such as
autoPatchelf. Rust declares patchelf explicitly and accepts either single-output or
split-output compiler runtimes through `lib.getLib`.

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

`platforms.nix` is derivation-affecting: its loader paths and architecture settings reach
build commands. Moving existing values behind its interface is neutral; changing those
values changes the builds which consume them.

**There is no `mkTvpDerivation`.** A shared wrapper around `stdenv.mkDerivation` is the
most tempting thing to put here, and it is exactly the shared builder that start-version
files exist to avoid — hidden one level up. Builders call `stdenv.mkDerivation` directly.

## `checks` vs `testBatches`

| Output | Holds |
|---|---|
| `checks` | repo-wide invariants only — the package set evaluates, formatting is clean |
| `testBatches` | one buildable handle per package's suite, so CI gets a work unit per job |

`testBatches.<system>.all` also includes all base suites, named bootstrap variants and
repository checks. Declared broken versions are excluded with their recorded reasons.
It is separate from `checks`, so `nix flake check` remains a short invariant check.

```sh
nix build .#testBatches.x86_64-linux.all --keep-going --no-link
```

For a detached run with persistent progress and wall-clock timing:

```sh
nix run .#test -- start
nix run .#test -- status
nix run .#test -- status --json
tail -f .tvp-tests/latest/nix.log
nix run .#test -- wait
nix run .#test -- stop
```

`start` materialises `testPlans.<system>` and launches one Nix build with `--keep-going`.
Nix schedules and shares dependencies across the whole graph, using its configured
resource settings. Optional `--jobs` and `--cores` override those settings. Valid cached results
are reused; this does not force unchanged packages to rebuild.

Each run under `.tvp-tests/runs/` contains its frozen source/derivation plan, declared
exclusions, readable Nix log, filtered activity events and atomic JSON status. Debug
cache-query traffic is discarded; full build logs remain available through `nix log`.
Progress queries inspect each test's valid store outputs, so a suite passes as soon as
all its tests pass, even if Nix has deferred its summary derivation. Reports include
both suite totals and individual test/check totals. Activity events provide live build
names and phases. The report distinguishes cached-at-start suites, passed suites and failed-or-blocked suites;
elapsed time becomes the measured total on completion. It does not infer a reliable ETA
from suite counts, because suite costs and shared prerequisites vary.
Nix failure messages mark affected tests and suites failed-or-blocked during the run;
unresolved work remains pending until Nix finishes. Valid successful outputs take
precedence over error messages. Historical Nix failure diagnostics, including failures
in shared prerequisites, remain available in JSON and `nix.log`.

The runner and plan are garbage-collection roots, and completed suites are rooted as
they finish. Later worktree edits do not change a run already in progress. The printed
frozen-runner command can inspect the run without re-evaluating the current worktree.
The current `status` command can also inspect older frozen plans and recover their test
membership without changing the running build.
For a repaired recipe, link its focused validation back to the original run:

```sh
nix run .#test -- start --state-dir .tvp-tests/retries \
  --retry-of .tvp-tests/runs/ORIGINAL --only openssl_1_0_0
```

The original run's `status` and `wait` use the latest linked attempt for each
retried suite. A successful retry replaces the old failure; an unfinished retry
is pending. Unrelated runs never override results automatically. `status --json`
retains attempt provenance and historical errors; `status --attempt-only` shows
the selected frozen attempt without retry results. Original logs are preserved.
`--run PATH` selects an earlier run; `--only NAME` on `start` selects an exact suite for
a focused run. `wait` returns nonzero on failure or interruption. Removing an inactive
run directory releases its roots. `.tvp-tests/` is ignored by Git.

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

## Python profiles and Go bootstrap

`python-minimal` and `python-build` retain their independently pinned build-interpreter
profiles. The `python` family supplies general-purpose interpreters with explicit TLS,
FFI, databases, terminal and compression inputs, plus upstream's bundled ensurepip for
offline virtual environments. Tk, the optional native UUID helper and NIS omissions are
recorded in the profile rather than left to host detection. Python 3.5/3.6 use the existing
GCC 9 compatibility base; 3.7 onward use the owned default. Python 3.5 uses the named
`ncurses64` Readline variant and matching Ncurses 6.4 public WINDOW headers. Library and compiler ceilings
live in version definitions; modern C API tests remain alongside guarded legacy consumers.

`go-bootstrap_20171003` builds upstream's dated C-source bootstrap distribution. Its archive
retains `go1.4-bootstrap-20170531` in VERSION; the package records both facts explicitly.
Regular `go` definitions pin an earlier compiler through `deps.bootstrap`. The chain is
C bootstrap → Go 1.17.13 → 1.20.14 → 1.22.12 → 1.24.13 → 1.27.3. Every stage builds from
source. Native Go OS/architecture and ELF loader settings come from the platform interface;
C/C++ compiler defaults are pinned to the selected base. Cross compilation is not implied.
Automatic toolchain and module downloads are disabled during builds and validation.
Go 1.22+ also defaults its installed toolchain selection to `local`, so a version pin
does not silently select a downloaded compiler; explicit user overrides still work.

For example, `nix shell .#python_3_12_16 .#go_1_27_3` selects those canonical toolchains.
The Python suite tests native extensions, embedding, offline venv/pip, standard-library
behavior and exact library linkage. Go tests include offline local modules, cgo and its
owned loader/libc, and standard-library tests.

## Dart, Flutter and Android SDK components

`pkgs/data/` holds versioned build/runtime data such as the dated Mozilla CA bundle.
`pkgs/sdks/` holds Flutter and independent Android component families. Android platform
versions include the upstream revision: `android-platform_36_r2` is API 36 revision 2,
and `android-platform_37_2_r2` is API 37.2 revision 2.

Dart 3.13.7's VM, native compiler and language tools build from source using the exact
upstream Dart bootstrap and DEPS revisions, owned GN, LLVM and LLD. DevTools web assets
remain an explicit binary input. Flutter 3.47.8 rebuilds its command snapshot from Dart
sources using this SDK. Its engine, frontend snapshots and web artifacts remain pinned
upstream binaries. Android components and Gradle likewise declare their binary/bytecode
provenance and the source bootstrap work that would replace it.

Choose SDK components independently; a profile joins their existing outputs:

```nix
sdk = tvp.android.mkSdk {
  components = with tvp.packages; [
    android-commandline-tools_23_0
    android-platform-tools_37_0_1
    android-platform_36_r2
    android-build-tools_36_0_0
    android-ndk_28_2_13676358
  ];
};

# In a derivation or development shell:
nativeBuildInputs = [ sdk tvp.packages.gradle_9_3_1 ];
```

`tvp.android.profiles.flutter` selects those versions for Flutter 3.47. The `latest`
profile selects API 37.2 r2, Build Tools 37.0.0 and NDK 30.0.16248370. Each profile may
contain multiple platform, Build Tools and NDK versions; duplicate component paths and
multiple command-line tools versions are rejected. Component selection adds links and
keeps each component's canonical build graph intact. The lower-level constructor is
`tvp.lib.android.mkSdk { stdenv = ...; components = ...; }`.

Profiles provide `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `android`, `sdkmanager`, `adb`,
`fastboot` and `tvp-android-sdk`. The latter prints the writable SDK directory. SDK locks
live in an atomic per-output cache under `$XDG_CACHE_HOME/tvp/android`, or the build
scratch directory inside Nix. Flutter similarly prepares a per-output writable SDK
under `$XDG_CACHE_HOME/tvp/flutter`; `TVP_FLUTTER_CACHE` selects another cache parent.
Initial copies preserve timestamps so the built tool snapshot stays valid. Components
and Android target sysroots retain their store paths; target sysroot and compiler
runtime bytes are checked against the original NDK archives after fixup.

The flake permits the six explicitly selected Android distribution families while
retaining their upstream unfree licence metadata. Library consumers importing their own
`pkgs` configure `allowUnfreePredicate` for `android-cli`, `android-commandline-tools`,
`android-platform-tools`, `android-build-tools`, `android-platform` and `android-ndk`.
Command-line Tools 23's auto-downloading launcher is replaced by the separately pinned
Android CLI. Upstream `android sdk list` still contacts its repository for package lists.

Gradle's `tvp-gradle-seed-wrapper` seeds the exact verified `9.3.1-all.zip` into the
selected `GRADLE_USER_HOME`. The upstream Wrapper verifies and installs that archive;
its checksum and success-marker handling remain intact. Flutter invokes this helper
and preloads the SDK's exact bundled pub archives. Package checks run offline: Dart
JIT/AOT/JS/Wasm compilation, FFI and pub; Flutter widget execution, web compilation and
Android ARM64 AOT assembly; NDK C/C++ cross linking and `ndk-build`; and signed APK
construction using Android Build Tools. Cross-produced Android artifacts are inspected
on the host. Devices, emulators and Flutter GTK desktop execution are separate work.
A complete Flutter Gradle APK also needs the application's Maven/plugin dependencies;
this initial profile does not provide a locked offline Maven repository.

Git, curl, nghttp2 and CA data support these SDKs as normal versioned packages. curl's
initial profile enables OpenSSL, HTTP/2, gzip and zstd, with local HTTP/TLS checks. Git
checks repositories, PCRE2 matching, packing and HTTP clones. Nix's syscall filter
prevents the setgid operations in Git's initialization fixture; that complete unchanged
fixture was additionally validated natively. ADB initializes `~/.android` even for its
version command, so its startup/version was validated natively alongside the sandboxed
component revision and fastboot checks. A native/VM CI stage should retain those two
supplementary checks.

## Runtime cleanup and permanent audits

`gcc13-owned-v2` reuses the first owned base's compiler, libc and floor, and adds an
owned patchelf-backed RPATH cleanup hook. V3 retains these producers and revises the
consumer protocol, including response-file expansion and wrapper support metadata.
The GCC16 generation carries the v2/v3 consumer protocol and regression tests.
Both `default` and `gcc16` select GCC16. Earlier GCC13 generations remain pinned bootstrap inputs; GCC13-v3 also
serves the two measured ACL compatibility consumers. The original constructor's empty fixup-input selection computes the
same earlier base and bootstrap producers.

The v2 hook removes unused ELF search directories. A package declares store library
directories required for name-based `dlopen` in `runtimeLibraryPaths`; these are
preserved even without `DT_NEEDED` entries. `dontShrinkRpaths` opts out for packages
whose output format needs a different fixup procedure. Static executables are retained.
The base fixture runs linked/dlopen consumers, a symlinked executable, static code,
multiple outputs and the explicit opt-out profile.

Canonical JDK 21.0.13 follows the default base. Its procedure cleans the exploded JDK
before building module images, so `jpackage` launchers embedded in `lib/modules` and
jmods receive the same cleanup as ordinary installed ELF files. The superseded JDK base variant is
retired; earlier TVP revisions retain its original graph. Shared tests cover JNI, subprocesses,
image creation, a real generated application launcher, offscreen font rendering and
PostScript printing. Loader traces verify owned Fontconfig/CUPS loading; the trimmed
profile additionally rejects the boot JDK, file utility and X11 inputs in its closure.

`checks.package-runtime-ownership` reads an exported Nix reference graph for every
buildable canonical package and SDK composition. Registration includes canonical, variant and private bootstrap
outputs, the owned bases' explicitly declared private paths and SDK profiles.
The audit walks references transitively per root, without calling a Nix daemon from
inside the build sandbox.

Existing foreign runtime debt is recorded in `audits/runtime-baseline.json` with exact
paths, a reason and required follow-up per package. It covers borrowed compatibility
bases, historical borrowed dependencies and retained binary toolchain references.
A path accepted for one package is not accepted for another. New foreign paths fail;
removed roots or cleared debt also require a reviewed baseline update. Binary seeds
receive the same regression check. This freezes known debt without describing it as
complete ownership. `checks.audit-contracts` exercises these failure cases and graph
comparison behavior; `checks.provenance-declarations` rejects precompiled provenance
without a declared binary boundary and checks context-free reporting manifests.

`nix run .#provenance -- --json` reports each root's declared `source`, `mixed` or
`binary` origin separately from registered closure membership. `runtimeBoundaries`
lists registered binary/mixed components reached at runtime; `foreignPaths` lists
exact unregistered store paths. The legacy JSON field `owned` measures registration,
not compilation from source. Private owned-base components are registered rather than
misreported as foreign packages with matching version names.

## Producer graph comparison and CI entry points

`nix eval .#graph --json` or `nix run .#neutral -- --graph save FILE` captures the
canonical, variant, base/alias, private component, bootstrap, consumer and SDK producer
identities. `nix run .#neutral -- --graph diff BEFORE --json` compares them by exact
name. New entries pass; removed entries and changes fail. Deliberate changes require
repeatable `--allow-change EXACT_NAME` arguments, and unused allowances fail. The JSON
keeps before/after values for reviewed changes. `--out` compares outputs for verified
transport changes; the original canonical-only text commands remain available.

`ci/validate.sh` provides a foreground exit code around the existing full-suite runner.
`start --json` returns the exact frozen run identity; CI waits on that identity rather
than following a movable `latest` alias. Final machine-readable status is retained in
the run directory. `ci/builder-preflight.sh` performs read-only Linux inventory and
prints selected Nix settings without dumping configuration tokens. See
[the builder handoff](ci/README.md) for the existing-distribution setup and deployment
boundaries. Host provisioning, repository CI activation and publishing remain separate
from the local validation entry points.

Retired bootstrap generations retain full validation under
`testBatches.x86_64-linux.bootstrap-base-gcc13`,
`testBatches.x86_64-linux.bootstrap-base-gcc13-owned`,
`testBatches.x86_64-linux.bootstrap-base-gcc13-owned-v2`,
`testBatches.x86_64-linux.bootstrap-base-gcc13-owned-v3` and the corresponding
`bootstrap-PROFILE-PACKAGE` batches. The active base suite is
`testBatches.x86_64-linux.base-gcc16-owned`. All are included in the full plan.
Graph snapshots expose their producers under `bootstrapBases`, `bootstrapVariants`,
`bootstrapComponents`, `bootstrapStages` and `bootstrapConsumers`.
