# Frozen x86_64-linux construction identities from d6226e0. A consumer protocol
# change must not rebuild the parent compiler, its variants, or compat bases.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  expected = builtins.fromJSON (builtins.readFile ./construction-v2.json);
  entries = tvp.graph.entries;
  changed = lib.filterAttrs (name: drv: (entries.${name}.drv or null) != drv) expected;
  oldComponents = lib.filterAttrs (
    name: _: lib.hasPrefix "bootstrapComponents.gcc13-owned-v2." name
  ) entries;
  componentMismatch = lib.filterAttrs (
    name: value:
    value.drv != entries.${
      lib.replaceStrings [ "bootstrapComponents.gcc13-owned-v2." ] [ "components.gcc13-owned-v3." ] name
    }.drv
  ) oldComponents;
in
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
if changed != { } || componentMismatch != { } then
  throw "TVP: construction/component identities changed: ${
    lib.concatStringsSep ", " (lib.attrNames (changed // componentMismatch))
  }"
else
  pkgs.runCommand "tvp-construction-preserved-v3" { } ''
    printf '%s\n' '${toString (builtins.length (lib.attrNames expected))} frozen construction identities; v3 components equal v2' > "$out"
  ''
