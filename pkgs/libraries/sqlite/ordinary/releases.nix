# Native-only source/launcher boundaries; retained releases stay unchanged.
{
  pkgs,
  tvpLib,
  defs,
}:
let
  table = tvpLib.packages.mkTable (import ../3.nix { inherit defs; });
  select =
    version: definition:
    if definition.name == "3.1.2" && pkgs.lib.versionAtLeast version "3.2.5" then
      defs."3.2.5"
    else if definition.name == "3.1.2" && pkgs.lib.versionAtLeast version "3.2.3" then
      defs."3.2.3"
    else if definition.name == "3.4.2" && pkgs.lib.versionAtLeast version "3.5.7" then
      defs."3.5.7"
    else if definition.name == "3.4.2" && pkgs.lib.versionAtLeast version "3.5.6" then
      defs."3.5.6"
    else if definition.name == "3.6.4" && pkgs.lib.versionAtLeast version "3.6.7" then
      defs."3.6.7"
    else if definition.name == "3.6.10" && pkgs.lib.versionAtLeast version "3.6.12" then
      defs."3.6.12"
    else
      definition;
in
pkgs.lib.mapAttrs (version: entry: entry // { def = select version entry.def; }) table
