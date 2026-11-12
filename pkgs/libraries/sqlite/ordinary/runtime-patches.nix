# Source facts, shared as data. No builder imports or recipe result wrappers.
{ lib }:
name:
let
  within = start: end: lib.versionAtLeast name start && lib.versionOlder name end;
in
lib.optionals (within "3.0.0" "3.0.7") [
  {
    file =
      if lib.versionOlder name "3.0.2" then
        ../patches/legacy-test-pointer-3.0.0.patch
      else if name == "3.0.2" then
        ../patches/legacy-test-pointer-3.0.2.patch
      else if name == "3.0.3" then
        ../patches/legacy-test-pointer-3.0.3.patch
      else
        ../patches/legacy-test-pointer-3.0.4.patch;
    reason = "Correct both pager and B-tree test adapters' complete pointer formatting/parsing on64-bit hosts, including object arguments; upstream corrected these pointer roles in3.0.7. Non-pointer integers and tests stay unchanged.";
  }
]
++ lib.optionals (within "3.0.0" "3.3.8") [
  {
    file =
      if name == "3.0.0" then
        ../patches/legacy-test-tcl-init-3.0.0.patch
      else
        ../patches/legacy-test-tcl-init.patch;
    reason = "Initialize the selected Tcl library in the old test interpreter before the unchanged clock-dependent date tests; check Tcl_Init and propagate errors.";
  }
]
++ lib.optionals (within "3.1.0" "3.3.14") [
  {
    file = ../patches/legacy-corrupt2-rdwr.patch;
    reason = "Backport upstream3.3.14's four append-to-RDWR fixture corrections so seek writes corrupt the intended header instead of appending; expected errors remain exact.";
  }
]
++ lib.optionals (within "3.1.1" "3.7.6") [
  {
    file =
      if lib.versionOlder name "3.3.0" then
        ../patches/legacy-serial-width-declaration.patch
      else
        ../patches/legacy-serial-width-assignment.patch;
    reason = "Avoid signed INT64_MIN negation when choosing integer serialization width; defined unsigned magnitude preserves the original result for all other values and the width required for INT64_MIN.";
  }
]
++ lib.optionals (within "3.46.0" "3.48.0") [
  {
    file = ../patches/legacy-recovery-output-isolation.patch;
    reason = "Remove a previous test's recovery destination before saving the recovery fault fixture; the same original two-file workload otherwise inherits a deliberately truncated database and fails four zero-fault cases.";
  }
]
