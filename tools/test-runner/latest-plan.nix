# Metadata only: selection and version policy remain in latestTests.
{ flake, system }:
let
  f = builtins.getFlake flake;
  l = f.latestTests.${system};
  plain = builtins.unsafeDiscardStringContext;
  ident = d: {
    drv = plain d.drvPath;
    out = plain d.outPath;
    outputs = builtins.listToAttrs (
      map (n: {
        name = n;
        value = plain d.${n}.outPath;
      }) d.outputs
    );
  };
in
{
  schema = "tvp.latest-descriptor/v1";
  source = f.outPath;
  # A text store object referencing recipes protects them without realizing any
  # application. Never feed .drv paths to nix-store --realise for GC rooting.
  recipeManifest = builtins.toFile "tvp-latest-recipes" (
    builtins.unsafeDiscardOutputDependency l.all.drvPath
  );
  inherit system;
  metadata = l.metadata;
  requiredOutputs = map plain l.requiredOutputs;
  aggregate = ident l.all;
  batches = builtins.mapAttrs (
    _: b:
    (ident b)
    // {
      tests = builtins.mapAttrs (_: d: ident d) b.testSuite;
    }
  ) l.batches;
}
