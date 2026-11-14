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
  testContext ? null,
  argumentDefaults ? null,
}:
let
  steps = import ./build-steps.nix;
  toolProviders = import ./tool-providers.nix;
  build = import (if owned then ./owned-build.nix else ./native-build.nix) { inherit lib; };
  declared = builtins.functionArgs recipe;
  call =
    current: edits: customized:
    let
      unknown = lib.subtractLists (builtins.attrNames declared) (builtins.attrNames current);
      resolved =
        if argumentDefaults == null then
          current
        else
          builtins.intersectAttrs declared (argumentDefaults {
            arguments = current;
            inherit specification;
          })
          // current;
      definition = recipe resolved;
      # A field introduced by an arbitrary edit is not automatically a recipe
      # input. Only published fields or an explicit projection describe providers.
      published = builtins.attrNames (
        if builtins.isFunction definition then definition specification else definition
      );
      specification = lib.fix (
        final:
        builtins.foldl' (spec: edit: edit spec) (
          if builtins.isFunction definition then definition final else definition
        ) edits
      );
      plan = specification.plan;
      package = build specification;
      # Edits change the effective providers as well as their build steps.
      # Older recipes may keep a dependency only in their arguments.
      # A runtime override may replace a default input without changing the
      # construction provider. Only explicitly declared dependency names can be
      # projected here; recipes without a projection retain the old behavior.
      dependencyProviders = specification.dependencyProviders or { };
      # Collect only active production providers; upstream plans may depend on A.
      usedTools =
        if !owned then
          { }
        else
          let
            parts = steps.partition plan;
            active = builtins.filter (step: step.enabled or true) (parts.first ++ parts.second);
          in
          toolProviders.collect (
            [
              (toolProviders.tag "bash" specification.bash)
              (toolProviders.tag "coreutils" specification.coreutils)
            ]
            ++ builtins.concatMap (step: step.tools or [ ]) active
          );
      dependencies =
        usedTools
        // (lib.mapAttrs
          (
            name: original:
            dependencyProviders.${name}
              or (if builtins.elem name published then specification.${name} or original else original)
          )
          (
            builtins.intersectAttrs (lib.genAttrs (
              if builtins.isFunction dependencyNames then dependencyNames specification else dependencyNames
            ) (_: null)) resolved
          )
        );
      provenance = metadata // {
        base = specification.base.name;
        baseConstruction = specification.base.construction or null;
        cc =
          if owned && specification.base ? compiler then
            specification.base.compiler
          else
            specification.base.stdenv.cc;
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
            outputs = null;
            pname = null;
            version = null;
            src = null;
            stdenv = null;
            compiler = null;
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
                current // (if builtins.isFunction overrides then overrides resolved else overrides)
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
        // lib.optionalAttrs (testContext != null) {
          testContext = testContext result;
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
      lib.subtractLists (builtins.attrNames dependencies) (builtins.attrNames dependencyProviders) != [ ]
    then
      throw "TVP native recipe: dependency provider projection contains undeclared names"
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
