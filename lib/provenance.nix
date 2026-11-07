{ lib }:
rec {
  sourceKind =
    package:
    if !(package.tvp ? blob) then
      "source"
    else if builtins.elem lib.sourceTypes.fromSource (package.meta.sourceProvenance or [ ]) then
      "mixed"
    else
      "binary";

  # Registration is ownership of a package definition, not a claim that every
  # byte was compiled from source. No string context may force a report to build.
  registry =
    {
      canonical,
      variants,
      bases,
      compositions ? { },
      construction ? {
        bases = { };
        variants = { };
      },
    }:
    let
      buildable = lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken");
      packageRows =
        kind: packages:
        lib.concatMap (
          name:
          let
            p = packages.${name};
          in
          map (output: {
            inherit name kind output;
            path = builtins.unsafeDiscardStringContext p.${output}.outPath;
            source = sourceKind p;
            base = p.tvp.base or null;
            blob = p.tvp.blob or null;
          }) p.outputs
        ) (lib.attrNames (buildable packages));
      referenceRows =
        packages:
        lib.concatMap (
          name:
          let
            p = packages.${name};
          in
          lib.imap0 (i: reference: {
            name = "reference:${name}:${toString i}";
            kind = "definition-reference";
            output = reference.outputName or "out";
            path = builtins.unsafeDiscardStringContext (toString reference);
            source = "source";
            base = p.tvp.base or null;
            blob = null;
          }) (p.specification.base.referencePackages or [ ])
        ) (lib.attrNames (buildable packages));
      # A definition can select a customized TVP recipe without publishing it
      # as a named variant. Register that declared build, not its entire closure.
      dependencyRows =
        packages:
        let
          isRecipeOverride =
            p:
            let
              selection = p.__tvpSelection or { };
              original = canonical.${selection.canonical or ""} or null;
            in
            lib.isDerivation p
            && lib.elem (selection.namespace or null) [
              "canonical"
              "packages"
            ]
            && (selection.kind or null) == "override"
            && original != null
            && (p.tvp.customization.customized or false)
            && (p.tvp.builder or null) != null
            && (p.tvp.definition or null) != null
            && p.tvp.builder == (original.tvp.builder or null)
            && p.tvp.definition == (original.tvp.definition or null);
          overrides = lib.concatMapAttrs (
            owner: p:
            lib.mapAttrs' (dependency: value: lib.nameValuePair "${owner}/${dependency}" value) (
              lib.filterAttrs (_: value: isRecipeOverride value) (p.tvp.declaredDependencies or { })
            )
          ) (buildable packages);
        in
        packageRows "definition-dependency" overrides ++ referenceRows overrides;
      registeredBases =
        bases
        // lib.mapAttrs' (name: b: lib.nameValuePair "bootstrap.${name}" b) construction.bases;
      baseRows = lib.concatMap (
        name:
        let
          b = registeredBases.${name};
        in
        map (p: {
          name = "base:${name}";
          kind = "base";
          output = "out";
          path = builtins.unsafeDiscardStringContext "${p}";
          source = "substrate";
          base = name;
          blob = null;
        }) b.ownership.allowedRuntimePaths
      ) (lib.attrNames (lib.filterAttrs (_: b: b ? ownership) registeredBases));
    in
    packageRows "canonical" canonical
    ++ referenceRows canonical
    ++ dependencyRows canonical
    ++ lib.concatMap (
      profile:
      (entries: packageRows "variant" entries ++ referenceRows entries ++ dependencyRows entries) (
        lib.mapAttrs' (name: p: lib.nameValuePair "${profile}/${name}" p) variants.${profile}
      )
    ) (lib.attrNames variants)
    ++ lib.concatMap (
      profile:
      (entries: packageRows "bootstrap" entries ++ dependencyRows entries) (
        lib.mapAttrs' (
          name: p: lib.nameValuePair "bootstrap/${profile}/${name}" p
        ) construction.variants.${profile}
      )
    ) (lib.attrNames construction.variants)
    ++ baseRows
    ++ lib.mapAttrsToList (name: p: {
      inherit name;
      kind = "composition";
      output = "out";
      path = builtins.unsafeDiscardStringContext p.outPath;
      source = "composition";
      base = null;
      blob = null;
    }) compositions;
}
