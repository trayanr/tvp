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
  # These are selected identities, never path-info queries or realization claims.
  providerFacts = provider: {
    name = provider.pname or (provider.name or null);
    version = provider.version or null;
    drvPath = provider.drvPath or null;
    # outPath would make Nix JSON coerce this whole record to a store string.
    path = provider.outPath;
    builtBy = provider.tvp.base or null;
    selection =
      if provider ? __tvpSelection then
        builtins.intersectAttrs {
          kind = null;
          category = null;
          namespace = null;
          name = null;
          operation = null;
          reason = null;
        } provider.__tvpSelection
      else
        null;
  };
  buildContext =
    row: p:
    let
      base = p.specification.base or null;
      stdenv = if base != null && base ? stdenv then base.stdenv else p.stdenv or null;
      compiler =
        if base != null && base ? compiler then
          base.compiler
        else if stdenv != null then
          stdenv.cc or null
        else
          null;
      platform =
        if base != null && base ? platform then
          base.platform
        else if stdenv != null then
          stdenv.hostPlatform or { }
        else
          { };
      # Reading names is lazy in the values. Do not map providerFacts over tools:
      # an unused provider can depend on the package currently being described.
      catalogue =
        if base == null then
          { }
        else if builtins.isAttrs (base.tools or null) then
          base.tools
        else
          (base.standardTools or { })
          // {
            bash = base.shell;
            coreutils = base.coreutils;
            binutils = compiler.bintools;
          };
      dependencies = p.tvp.deps or { };
      roleFor =
        name: provider:
        let
          numbered = builtins.match "(.+)#[0-9]+" name;
          role = if numbered == null then name else builtins.head numbered;
        in
        if !(builtins.isAttrs provider && provider ? outPath) then
          null
        else
          provider.__tvpToolRole or (
            if builtins.hasAttr name catalogue then
              name
            else if builtins.hasAttr role catalogue then
              role
            else
              null
          );
      usedTools = builtins.listToAttrs (
        lib.concatMap (
          name:
          let
            provider = dependencies.${name};
            role = roleFor name provider;
          in
          lib.optional (role != null && builtins.isAttrs provider && provider ? outPath) {
            inherit name;
            value = providerFacts provider // {
              inherit role;
              origin =
                if builtins.hasAttr role catalogue && provider.outPath == catalogue.${role}.outPath then
                  "selected-base"
                else
                  "package-dependency";
            };
          }
        ) (builtins.attrNames dependencies)
      );
    in
    if row.status.level == "broken" || row.constructor == "unavailable" || compiler == null then
      null
    else
      {
        system = platform.system or (p.system or system);
        config = platform.config or (stdenv.hostPlatform.config or null);
        base = {
          name = p.tvp.base or (base.name or null);
          construction = base.construction or null;
        };
        compilerVersion = (compiler.underlyingDriver or compiler).version or null;
        gcc = providerFacts compiler;
        binutils = providerFacts compiler.bintools;
        libc = providerFacts compiler.libc;
        inherit usedTools;
      };
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
        buildContext = buildContext row p;
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
