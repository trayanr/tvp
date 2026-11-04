# Internal opt-in recipe call. Retain arguments/edits outside mkDerivation and
# re-enter the same decoration for both customization routes and projections.
{
  lib,
  owned ? false,
}:
{
  recipe,
  args,
  dependencyNames,
  metadata,
  selection,
  mkTests,
  infrastructure ? { },
  passthru ? { },
}:
let
  steps = import ./build-steps.nix;
  build = import (if owned then ./owned-build.nix else ./native-build.nix) { inherit lib; };
  declared = builtins.functionArgs recipe;
  call =
    current: edits: customized:
    let
      unknown = lib.subtractLists (builtins.attrNames declared) (builtins.attrNames current);
      definition = recipe current;
      specification = lib.fix (
        final:
        builtins.foldl' (spec: edit: edit spec) (
          if builtins.isFunction definition then definition final else definition
        ) edits
      );
      plan = specification.plan;
      package = build specification;
      dependencies = builtins.intersectAttrs (lib.genAttrs (
        if builtins.isFunction dependencyNames then dependencyNames specification else dependencyNames
      ) (_: null)) current;
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
          operation = "recipe/spec";
        };
      finalMetadata = (package.tvp or { }) // provenance;
      finalTests = mkTests result;
      decorate =
        value:
        let
          reselect =
            changed:
            if owned && builtins.length package.outputs > 1 then changed.${value.outputName} else changed;
        in
        lib.optionalAttrs owned ((package.passthru or { }) // passthru)
        // value
        // lib.optionalAttrs owned (
          builtins.intersectAttrs {
            pname = null;
            version = null;
            src = null;
            stdenv = null;
            meta = null;
            runtime = null;
            development = null;
            buildEnvironment = null;
            artifact = null;
            buildStepRunner = null;
          } package
        )
        // {
          __tvpSelection = selected;
          tvp = finalMetadata;
          tests = finalTests;
          all = finalAll;
          override =
            overrides:
            reselect (
              call (
                current // (if builtins.isFunction overrides then overrides current else overrides)
              ) edits true
            );
          edit = edit: reselect (call current (edits ++ [ edit ]) true);
          editSteps =
            edit: reselect (call current (edits ++ [ (spec: spec // { plan = edit spec.plan; }) ]) true);
          editRuntime =
            edit:
            reselect (
              call current (edits ++ [ (spec: spec // { runtime = edit (spec.runtime or { }); }) ]) true
            );
          specification = specification;
          buildSteps = plan;
        }
        // lib.optionalAttrs (owned || specification ? passthru) {
          passthru =
            (package.passthru or { })
            // passthru
            // {
              tvp = finalMetadata;
              tests = finalTests;
            };
        };
      outputs = lib.genAttrs package.outputs (name: decorate package.${name} // outputs);
      finalAll = map (value: decorate value // outputs) package.all;
      result =
        decorate package
        // outputs
        // {
          all = finalAll;
        };
    in
    if unknown != [ ] then
      throw "TVP native recipe: unknown arguments: ${lib.concatStringsSep ", " unknown}"
    else if
      owned
      && builtins.length package.outputs > 1
      && lib.intersectLists package.outputs (builtins.attrNames passthru) != [ ]
    then
      throw "TVP named outputs: output name collides with catalogue passthru metadata"
    else
      result;
in
call args [ ] false
