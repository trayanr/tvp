{ lib }:
{
  # "-" as well as ".", so patchlevel releases (1.8.7-p374) name consistently.
  attrName =
    pname: version:
    "${pname}_${
      lib.replaceStrings
        [
          "."
          "-"
        ]
        [
          "_"
          "_"
        ]
        version
    }";

  # Derivation-affecting: callers interpolate this into `src` URLs and install paths.
  majorMinor = version: lib.versions.majorMinor version;

  atLeast = bound: version: lib.versionAtLeast version bound;
  below = bound: version: lib.versionOlder version bound;
}
