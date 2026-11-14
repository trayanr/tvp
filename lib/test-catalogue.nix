# Context-free release/alias identities for selecting an honest partial plan.
# This never requests package outputs or changes the complete test plan.
{
  pkgs,
  canonical,
  packages,
  variants,
  batches,
  source,
  revision,
}:
let
  inherit (pkgs) lib;
  plain = builtins.unsafeDiscardStringContext;
  eligible = lib.filterAttrs (
    _: p: p ? tests && p.tests != { } && (p.tvp.status.level or "ok") != "broken"
  ) canonical;
  record = job: p: {
    inherit job;
    family = p.pname;
    inherit (p) version;
    jobDRV = plain batches.${job}.drvPath;
    packageDRV = plain p.drvPath;
    out = plain p.outPath;
    outputs = map (name: plain p.${name}.outPath) p.outputs;
  };
  grouped = lib.groupBy (name: eligible.${name}.pname) (lib.attrNames eligible);
  latest = (import ./tests.nix { inherit lib; }).selectLatest {
    inherit canonical packages batches;
  };
  families = lib.mapAttrs (
    family: names:
    let
      selected = latest.metadata.families.${family};
      job = selected.job;
    in
    {
      selector = selected.selector;
      alias = record job eligible.${job};
      versions = map (name: record name eligible.${name}) names;
    }
  ) grouped;
  profiles = lib.foldlAttrs (
    result: profile: entries:
    result
    // lib.mapAttrs' (
      name: p:
      let
        job = "variant-${profile}-${name}";
      in
      lib.nameValuePair job (record job p)
    ) (lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") entries)
  ) { } variants;
  declarations = {
    inherit families profiles;
  };
in
assert !(builtins.hasContext (builtins.toJSON declarations));
pkgs.writeText "tvp-representative-catalogue.json" (
  builtins.toJSON (
    declarations
    // {
      schema = "tvp.representative-catalogue/v1";
      subject = {
        inherit revision;
        system = pkgs.stdenv.hostPlatform.system;
        source = builtins.path {
          path = source;
          name = "tvp-test-source";
        };
      };
    }
  )
)
