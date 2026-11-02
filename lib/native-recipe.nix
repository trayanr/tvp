# Internal opt-in recipe call. Retain arguments/edits outside mkDerivation and
# re-enter the same decoration for both customization routes and projections.
{ lib }:
{
  recipe,
  args,
  dependencyNames,
  metadata,
  selection,
  mkTests,
  infrastructure ? { },
}:
let
  steps = import ./build-steps.nix;
  build = import ./native-build.nix { inherit lib; };
  declared = builtins.functionArgs recipe;
  call =
    current: edits: customized:
    let
      unknown = lib.subtractLists (builtins.attrNames declared) (builtins.attrNames current);
      specification = recipe current;
      plan = builtins.foldl' (plan: edit: edit plan) specification.plan edits;
      package = build (specification // { inherit plan; });
      dependencies = builtins.intersectAttrs (lib.genAttrs dependencyNames (_: null)) current;
      provenance = metadata // {
        base = specification.base.name;
        cc = specification.base.stdenv.cc;
        deps = dependencies;
        declaredDependencies = dependencies;
        declaredInfrastructure = infrastructure;
        infra = builtins.attrNames infrastructure;
        customization = {
          inherit customized;
          edits = builtins.length edits;
        };
      };
      selected =
        selection
        // lib.optionalAttrs customized {
          kind = "override";
          operation = "recipe/steps";
        };
      decorate =
        value:
        value
        // {
          __tvpSelection = selected;
          tvp = (package.tvp or { }) // provenance;
          tests = mkTests result;
          override = overrides: call (current // overrides) edits true;
          editSteps = edit: call current (edits ++ [ edit ]) true;
          buildSteps = plan;
        };
      outputs = lib.genAttrs package.outputs (name: decorate package.${name} // outputs);
      result =
        decorate package
        // outputs
        // {
          all = map (value: decorate value // outputs) package.all;
        };
    in
    if unknown != [ ] then
      throw "TVP native recipe: unknown arguments: ${lib.concatStringsSep ", " unknown}"
    else
      result;
in
call args [ ] false
