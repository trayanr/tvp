# Evaluation only: no private workflow inputs, store queries or derivation contexts.
{
  lib,
  canonical,
  variants,
  splitReport,
  latest,
  source,
  system,
  familyEntrypoints ? null,
}:
let
  packageFor =
    row:
    if row.namespace == "canonical" then
      canonical.${row.name}
    else
      variants.${lib.removePrefix "variants." row.namespace}.${row.name};
  facts = {
    schema = "tvp.migration-facts/v1";
    inherit source system;
    scope = splitReport.scope;
    authoring =
      if familyEntrypoints == null then
        null
      else
        {
          schema = "tvp.family-authoring-facts/v1";
          scope = "Registered ordinary family indexes; canonical non-broken releases only for row counts. Public variants are not additional indexes.";
          entries = map (entry: {
            category = builtins.head entry.namespaces;
            family = lib.last entry.namespaces;
            entrypoint = "pkgs/${lib.concatStringsSep "/" entry.namespaces}/default.nix";
            inherit (entry) recipes;
          }) familyEntrypoints;
        };
    rows = map (
      row:
      let
        p = packageFor row;
      in
      {
        inherit (row)
          id
          namespace
          name
          constructor
          compliant
          failure
          ;
        family = p.pname;
        version = p.version;
        status = row.status.level;
        selectedBase = p.tvp.base or (p.specification.base.name or null);
      }
    ) splitReport.rows;
    latest = {
      measurement = latest.measurement or "unspecified";
      runtimeQualifiedRows = null;
      families = lib.mapAttrs (_: entry: {
        inherit (entry) job version;
      }) latest.families;
      skipped = map (entry: { inherit (entry) family reason; }) latest.skipped;
    };
    splitPolicy = {
      inherit (splitReport)
        status
        success
        allSplit
        errors
        ;
    };
    outsideOrdinaryScope = {
      disposition = "Separate production adapter/base/bootstrap/composition audit required; not counted as completed ordinary recipes.";
      producers = lib.mapAttrs (_: entry: {
        inherit (entry) role disposition validation;
      }) splitReport.outsideOrdinaryScope.producers;
    };
  };
  # Strip source metadata contexts too; builtins.toFile must not realize recipes.
  json = builtins.unsafeDiscardStringContext (builtins.toJSON facts);
in
assert !(builtins.hasContext json);
builtins.fromJSON json
