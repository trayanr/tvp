ISL release family
==================

`build-0.20.nix` serves 0.20, 0.26, 0.27 and 0.28 with official `.tar.xz`
archives, system GMP 6.3.0, parallel building and upstream `make check`.
The latest `isl` and `isl_0` selectors follow 0.28. Exact 0.20 consumers,
including GCC and construction inputs, deliberately remain pinned.
Archive SHA256 pins establish content identity; they do not authenticate signatures.

0.20 installs `libisl.so.19`; these newer releases install `libisl.so.23`.
The 0.21 API boundary introduced `isl_size` and renamed the AST operator enum.
The C fixture explicitly selects the appropriate API instead of aliasing or
backporting it. Matching C++ headers are used only with their own library.
These checks make no old-GCC drop-in ABI compatibility claim.

The appended tests retain the original version and arithmetic leaves:

- `semantics` checks bounded integer sets, counting, existential projection,
  modular map images, inverse composition, affine expressions, lexicographic
  minima/maxima and coalescing using semantic equality. Empty piecewise `add`
  (domain intersection) and `union_add` (empty-domain identity) are separate controls.
- `cpp11` and `cpp17` compile and run matching generated bindings. 0.20 has no
  installed generated C++ header and records an explicit skip.
- `loaded-library` checks exact ISL and GMP paths with `dladdr`/`realpath`,
  matching versions, actual ELF SONAME and the GMP dependency. Its ELF assertions
  explicitly skip non-Linux platforms.
- `upstream-coverage` rebuilds the unmodified source with Python available only
  to tests, retaining live output, configuration, upstream logs and `.trs` results.
  It requires PASS for every expected enabled group. 0.20 has seven C/shell
  groups and no generated C++ suite. 0.26 ships unchecked C++11/C++17 bindings,
  but checked C++ and Python groups require the optional Clang interface generator.
  0.27/0.28 ship generated checked C++ and Python bindings and exercise those
  groups without Clang. Production packages do not acquire Python or Clang.
- `tracker` checks whole href basenames, compression deduplication, leading-zero
  version spelling and rejection of signatures, prereleases and filename junk.

Build a release's complete attached suite with, for example,
`nix build .#testBatches.x86_64-linux.isl_0_28`. The upstream report is
`nix run .#upstream -- --flake . isl`; use the same immutable source revision
for the app and `--flake` when recording a comparison. Missing versions in the
report are not claims that their archives are unavailable.
