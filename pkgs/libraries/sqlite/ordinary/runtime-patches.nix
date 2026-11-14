# Source facts, shared as data. No builder imports or recipe result wrappers.
{ lib }:
name:
let
  within = start: end: lib.versionAtLeast name start && lib.versionOlder name end;
in
lib.optionals (within "3.1.1" "3.7.6") [
  {
    file =
      if lib.versionOlder name "3.3.0" then
        ../patches/legacy-serial-width-declaration.patch
      else
        ../patches/legacy-serial-width-assignment.patch;
    reason = "Avoid signed INT64_MIN negation when choosing integer serialization width; defined unsigned magnitude preserves the original result for all other values and the width required for INT64_MIN.";
  }
]
++ lib.optionals (within "3.1.0" "3.2.2") [
  {
    file = ../patches/legacy-serial-signed-six-byte.patch;
    reason = "Use the signed48-bit maximum when choosing six-byte integer storage. The original unsigned48-bit bound truncates valid64-bit values and corrupts secondary-index rowids; this is the correct bound used by later upstream source.";
  }
]
