# Frozen x86_64-linux construction identities from d6226e0. A consumer protocol
# change must not rebuild the parent compiler, its variants, or compat bases.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  expected = builtins.fromJSON (builtins.readFile ./construction-v2.json);
  # These suites include a locale consumer outside the compiler components.
  # Its full legacy recipe graph is frozen alongside those components.
  expectedTests = {
    bootstrap-gcc13-gnugrep_3_11 = "/nix/store/4a55p88fl7mvym6jgj7nn0wc1c0ww913-tvp-tests-bootstrap-gcc13-gnugrep_3_11.drv";
    bootstrap-base-gcc13-owned = "/nix/store/n8dsmckwq8a7570ap8f18r75ib4jpawi-tvp-tests-bootstrap-base-gcc13-owned.drv";
  };
  changedTests = lib.filterAttrs (name: drv: tvp.testBatches.${name}.drvPath != drv) expectedTests;
  entries = tvp.graph.entries;
  changed = lib.filterAttrs (name: drv: (entries.${name}.drv or null) != drv) expected;
  oldComponents = lib.filterAttrs (
    name: _: lib.hasPrefix "bootstrapComponents.gcc13-owned-v2." name
  ) entries;
  componentMismatch = lib.filterAttrs (
    name: value:
    value.drv != entries.${
      lib.replaceStrings [ "bootstrapComponents.gcc13-owned-v2." ] [
        "bootstrapComponents.gcc13-owned-v3."
      ] name
    }.drv
  ) oldComponents;
in
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
if changed != { } || componentMismatch != { } || changedTests != { } then
  throw "TVP: construction/component identities changed: ${
    lib.concatStringsSep ", " (lib.attrNames (changed // componentMismatch // changedTests))
  }"
else
  pkgs.runCommand "tvp-construction-preserved-v3" { } ''
    printf '%s\n' '${toString (builtins.length (lib.attrNames expected))} frozen construction identities; v3 components equal v2' > "$out"
  ''
