# GNU Grep

`canonical.gnugrep_3_11` and `canonical.gnugrep_3_12` share `build-3.11.nix`
and retain PCRE2 10.44. `gnugrep` and `gnugrep_3` select 3.12.

```sh
nix build .#canonical.gnugrep_3_12
nix build .#testBatches.x86_64-linux.gnugrep_3_11 .#testBatches.x86_64-linux.gnugrep_3_12
nix run .#upstream -- --flake . gnugrep
```

The shared tests retain the original version and operation checks, and add
PCRE lookbehind and digit semantics with an explicit C.UTF-8 locale, shared-input
position after `-m2`, and the obsolete options' version-specific behavior.
Grep 3.11 overreads shared input when `-m2` writes to `/dev/null`; 3.12 fixes it.
Grep 3.11 also fails a recursive search of 100,000 empty files with
`Operation not supported` (exit 2); 3.12 correctly returns no matches (exit 1).
Upstream's `100k-entries` regression needs `RUN_EXPENSIVE_TESTS=yes`; ordinary
upstream checks skip it.
The warning-only `-u` / `--unix-byte-offsets` options in 3.11 are rejected in 3.12.
Historical behavior is preserved rather than patched.

The [GNU 3.12 announcement](https://lists.gnu.org/archive/html/info-gnu/2025-04/msg00008.html)
publishes the archive checksum. The upstream tracker reads the
[GNU mirror index](https://mirrors.kernel.org/gnu/grep/), accepts only complete
numeric release archive filenames, and deduplicates compression formats.
Signatures, prereleases and other files do not count as releases.
