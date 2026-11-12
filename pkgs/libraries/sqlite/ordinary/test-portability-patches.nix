# Narrow test-source facts only. No output rewriting or builder delegation.
{ lib }:
name:
let
  within = start: end: lib.versionAtLeast name start && lib.versionOlder name end;
in
lib.optionals (name == "3.0.0") [
  {
    file = ../patches/3.0.0-private-test-lock-diagnostics.patch;
    reason = "Backport upstream3.0.1's private TESTSRC pragma compilation and SQLITE_TEST lock diagnostics, including the matching pager prototype. Release-library debug policy and actual locking stay unchanged.";
  }
]
++ lib.optionals (within "3.0.0" "3.0.8") [
  {
    file = ../patches/legacy-test-attach2-journal-membership.patch;
    reason = "Backport upstream3.0.8's two lsort calls for leftover-journal membership assertions; retain the exact two filenames and reject every extra file.";
  }
]
++ lib.optionals (within "3.0.0" "3.5.9") [
  {
    file = ../patches/legacy-test-tcl-expr-reference.patch;
    reason = "Backport upstream3.5.9's direct Tcl expression-error reference; compare the entire callback error to the same interpreter's direct error without truncation.";
  }
]
++ lib.optionals (within "3.0.7" "3.5.6") [
  {
    file = ../patches/legacy-test-printf-zero-hex.patch;
    reason = "Correct only the zero hexadecimal alternate-form Tcl oracle to padded0, as the source formatter and upstream3.5.6 explicit vector require. Preserve every format call, integer vector and test name.";
  }
]
++ lib.optionals (within "3.1.0" "3.6.2") [
  {
    file = ../patches/legacy-test-tcl-text-inputs.patch;
    reason = "Construct fresh Tcl strings for the original5/7 TEXT fixtures, preserving SQL, blob bytes, values and text/text/null expectations. Upstream3.6.2 instead changes these inputs to A/B.";
  }
]
++ lib.optionals (within "3.2.3" "3.7.7") [
  {
    file = ../patches/legacy-test-types3-empty-string.patch;
    reason = "Force a string representation by append/remove through the generic Tcl command (avoiding its compiled typeless-empty shortcut), preserving the original empty value and exact string/TEXT expectation; upstream3.7.7's nonempty append establishes the same representation.";
  }
]
++ lib.optionals (within "3.5.9" "3.7.7") [
  {
    file =
      if lib.versionOlder name "3.6.3" then
        ../patches/legacy-test-nan-3.5.9.patch
      else if lib.versionOlder name "3.6.18" then
        ../patches/legacy-test-nan-3.6.3.patch
      else if lib.versionOlder name "3.7.0" then
        ../patches/legacy-test-nan-3.6.18.patch
      else
        ../patches/legacy-test-nan-3.7.6.3.patch;
    reason = "Backport upstream3.7.7 realnum_normalize/do_realnum_test verbatim, scoped to nan.test numeric infinity cases only. Preserve signs, NULL/type/payload checks and exact SQL CAST-to-text expectations; context boundaries retain each source's numeric cases.";
  }
]
