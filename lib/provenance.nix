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
    ++ lib.concatMap (
      profile:
      packageRows "variant" (
        lib.mapAttrs' (name: p: lib.nameValuePair "${profile}/${name}" p) variants.${profile}
      )
    ) (lib.attrNames variants)
    ++ lib.concatMap (
      profile:
      packageRows "bootstrap" (
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
