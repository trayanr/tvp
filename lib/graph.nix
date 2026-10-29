{ lib }:
{
  snapshot =
    {
      canonical,
      variants,
      bases,
      compositions ? { },
    }:
    let
      paths = p: {
        drv = builtins.unsafeDiscardStringContext p.drvPath;
        out = builtins.unsafeDiscardStringContext p.outPath;
      };
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
        // walk "compositions" compositions;
    };
}
