{ lib }:
{
  snapshot =
    {
      includeRootMetadata ? false,
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
      paths =
        p:
        {
          drv = builtins.unsafeDiscardStringContext p.drvPath;
          out = builtins.unsafeDiscardStringContext p.outPath;
        }
        // lib.optionalAttrs includeRootMetadata { outputs = [ (p.outputName or "out") ]; };
      walk =
        prefix: value:
        if lib.isDerivation value then
          { ${prefix} = paths value; }
        else if builtins.isAttrs value then
          lib.concatMapAttrs (name: child: walk "${prefix}.${name}" child) value
        else
          { };
      namedBases = lib.filterAttrs (name: b: b.name == name) bases;
    in
    {
      schema = 1;
      entries =
        walk "packages" canonical
        // walk "variants" variants
        // lib.mapAttrs' (
          name: b:
          lib.nameValuePair "bases.${name}" (
            (paths b.stdenv)
            // {
              canonical = b.name;
              builtBy = b.builtBy;
            }
          )
        ) bases
        // lib.concatMapAttrs (name: b: walk "components.${name}" (b.components or { })) namedBases
        // lib.concatMapAttrs (name: b: walk "bootstrap.${name}" (b.bootstrap or { })) namedBases
        // lib.concatMapAttrs (name: b: walk "consumers.${name}" (b.consumerPackages or { })) namedBases
        // walk "bootstrapVariants" construction.variants
        // lib.mapAttrs' (
          name: b:
          lib.nameValuePair "bootstrapBases.${name}" (
            (paths b.stdenv)
            // {
              canonical = b.name;
              builtBy = b.builtBy;
            }
          )
        ) construction.bases
        // lib.concatMapAttrs (
          name: b: walk "bootstrapComponents.${name}" (b.components or { })
        ) construction.bases
        // lib.concatMapAttrs (
          name: b: walk "bootstrapStages.${name}" (b.bootstrap or { })
        ) construction.bases
        // lib.concatMapAttrs (
          name: b: walk "bootstrapConsumers.${name}" (b.consumerPackages or { })
        ) construction.bases
        // walk "compositions" compositions;
    };
}
