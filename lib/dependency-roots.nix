# Lazy, context-free registrations for intended recipes, separate from selector intent.
{
  lib,
  graph,
  inventory,
  tools,
  checks,
  registry,
  borrowed,
  borrowedSource,
}:
let
  plain = builtins.unsafeDiscardStringContext;
  consumerLabels =
    row:
    if row.ownerScope == "ordinary" then
      "packages.${row.consumer}"
    else if row.ownerScope == "public-variant" then
      "variants.${builtins.replaceStrings [ "/" ] [ "." ] row.consumer}"
    else if row.ownerScope == "construction" then
      "bootstrapVariants.${builtins.replaceStrings [ "/" ] [ "." ] row.consumer}"
    else
      "compositions.${row.consumer}";
  owners = builtins.listToAttrs (
    map (row: lib.nameValuePair (consumerLabels row) row) inventory.consumers
  );
  scope =
    name:
    if lib.hasPrefix "packages." name then
      "canonical"
    else if lib.hasPrefix "variants." name then
      "variants"
    else if lib.hasPrefix "compositions." name then
      "composition"
    else if lib.hasPrefix "bootstrap" name then
      "construction"
    else
      "bases";
  roots =
    lib.mapAttrs (
      name: value:
      let
        status = owners.${name}.status or null;
        broken = (status.level or "ok") == "broken";
      in
      {
        scope = scope name;
        inherit status;
        drv = if broken then null else value.drv;
        outputs = value.outputs;
        evidence = "evaluated TVP graph registration";
      }
    ) graph.entries
    // lib.mapAttrs' (
      name: value:
      lib.nameValuePair "tools.${name}" {
        scope = "tools";
        status = null;
        drv = plain value.drvPath;
        outputs = value.outputs or [ "out" ];
        evidence = "evaluated TVP CLI definition";
      }
    ) tools
    // lib.mapAttrs' (
      name: value:
      lib.nameValuePair "checks.${name}" {
        scope = "checks";
        status = null;
        drv = plain value.drvPath;
        outputs = value.outputs or [ "out" ];
        evidence = "evaluated repository check definition";
      }
    ) checks;
in
{
  schema = 1;
  inherit roots;
  groups = builtins.listToAttrs (
    map
      (
        s:
        lib.nameValuePair s (
          builtins.attrNames (lib.filterAttrs (_: r: r.scope == s && r.drv != null) roots)
        )
      )
      [
        "canonical"
        "variants"
        "composition"
        "construction"
        "bases"
        "tools"
        "checks"
      ]
  );
  defaultGroup = "canonical";
  outputRegistrations = registry;
  borrowed = lib.mapAttrsToList (attribute: p: {
    drv = plain p.drvPath;
    inherit attribute;
    source = plain borrowedSource;
    evidence = "explicit attribute from pinned nixpkgs input";
  }) borrowed;
}
