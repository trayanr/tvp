# Diffutils

The 3.10 definition and `build-3.10.nix` serve 3.10, 3.11 and 3.12. All retain
exact Coreutils 9.5 for the `pr` helper used by `diff -l` and `diff -ly`.
`diff3` and `sdiff` use upstream's `diff` lookup through `PATH`; use the matching
package's `bin` directory first, or select `--diff-program=/absolute/path/to/diff`.
No runtime fixes are backported between releases.

## Historical behavior

[Upstream NEWS](https://git.savannah.gnu.org/cgit/diffutils.git/tree/NEWS?h=v3.12)
documents two regressions introduced in 3.11 and fixed in 3.12:

- Recursive comparison of an empty and nonempty regular file can print only a
  file-type summary instead of the expected diff (GNU bug 76452).
- Side-by-side comparison of nontrivial differences can crash (GNU bug 76613).
  `sdiff` also delegates to `diff -y`.

The exact 3.11 package retains both bugs. It remains buildable and useful for
other operations; a passing shared suite does not certify these regression cases.
The moving `diffutils` and `diffutils_3` aliases select 3.12.

These small reproductions use an isolated temporary directory and disable core
files. Set `diff` to the exact executable being examined and run each case
separately; differences normally return status 1:

```sh
diff=/absolute/path/to/bin/diff
(ulimit -c 0
 work=$(mktemp -d)
 trap 'rm -rf "$work"' EXIT
 cd "$work" || exit
 mkdir a b
 : > a/test
 printf 'content\n' > b/test
 "$diff" -Naur a b
)
```

3.10 and 3.12 emit a unified diff including `+content`; 3.11 emits a regular-file
summary. All three return 1, so checking only the exit status misses the bug.

```sh
diff=/absolute/path/to/bin/diff
(ulimit -c 0
 work=$(mktemp -d)
 trap 'rm -rf "$work"' EXIT
 cd "$work" || exit
 seq 1 100 > first
 { seq 1 49; seq 51 100; } > second
 "$diff" -yW 11 first second
)
```

3.10 and 3.12 print the side-by-side comparison and return 1; 3.11 can abort.
This fixture comes from upstream 3.12's `tests/side-by-side-seq`.

3.11 also intentionally changes filename quoting and symlink diagnostics,
adds multibyte case/whitespace handling, and fixes `cmp -s` on nonempty proc
files reporting zero size and `cmp` offsets/limits larger than integer ranges.
For example, UTF-8 `Δ`/`δ` under `diff -i` and U+2003/ASCII space under `diff -b`
compare equal in 3.11/3.12, but differ in 3.10. These historical distinctions
remain intact.

## Coverage

The shared suite keeps the original version, operation and pagination assertions.
`pagination-helper` verifies the declared absolute `pr` path and exercises `-l`
and simple `-ly` with an unusable `pr` placed first on `PATH`. `helpers` exercises
both default `PATH` lookup and explicit `--diff-program` selection for `diff3`
and `sdiff`. These helper fixtures do not exercise the nontrivial 3.11 crash.
The regression reproductions above are supplemental observations, not weakened
assertions or release-wide test exclusions.

Upstream tracking uses the GNU release directory. It captures whole archive
filenames and strictly normalises only numeric Diffutils release archives,
deduplicating compression formats. README files, signatures and diff suffixes
are excluded. The listing contains 17 available releases, with 3.10, 3.11 and
3.12 packaged; the other 14 are not packaged, rather than unavailable.
