# Ordinary family defaults; only declared procedure arguments are supplied.
{
  lib,
  api,
  defaultContext ? null,
}:
{
  pname,
  versionTable,
  source,
  tests,
  packageMeta ? { },
  testDeps ? { },
  context ? defaultContext,
}:
assert context != null || throw "TVP family: a selected build context is required";
let
  # Evaluation-only index origin. It certifies no builder/caller/runtime behavior.
  authoring = {
    origin = "tvp.lib.packages.mkFamily";
    model = "ordinary-family/v1";
  };
  constructor = context.builder;
  # Preserve the helper argument surface: GCC is selected through the base,
  # while explicit recipe dependencies named gcc remain ordinary dependencies.
  standardProviders = base: builtins.removeAttrs base.tools [ "gcc" ];
  defaults =
    { arguments, specification }:
    let
      base = arguments.base or context.base;
    in
    context.helpers
    // lib.genAttrs (builtins.attrNames (standardProviders base)) (
      name: (standardProviders specification.base).${name}
    )
    // {
      inherit base;
      inherit (specification.base.platform) goOS goArch dynamicLinker;
    };
  prepareDefinition =
    def:
    let
      declared = builtins.functionArgs (import def.builder);
      definitionConstructor = def.constructor or constructor;
      standardDependencies =
        specification:
        builtins.filter (name: declared ? ${name}) (
          builtins.attrNames (standardProviders specification.base)
        );
      additionalDependencies = def.dependencyNames or (builtins.attrNames def.deps);
    in
    def
    // {
      inherit authoring;
      constructor = definitionConstructor;
      base = def.base or context.base;
      helpers = def.helpers or { };
      dependencyNames =
        specification:
        lib.unique (
          (
            if builtins.isFunction additionalDependencies then
              additionalDependencies specification
            else
              additionalDependencies
          )
          ++ standardDependencies specification
        );
      testContext =
        def.testContext or (
          package:
          (import ./tests.nix { inherit lib; }).fromPackage {
            builder = definitionConstructor;
            inherit package;
          }
        );
    };
  prepareEntry = entry: entry // { def = prepareDefinition entry.def; };
  family = {
    inherit authoring;
    inherit
      pname
      source
      packageMeta
      testDeps
      ;
    versionTable = lib.mapAttrs (_: prepareEntry) versionTable;
    inherit instantiate;
    infra = {
      inherit lib;
    };
    argumentDefaults = defaults;
    extraArgs.mkTests = lib.makeOverridable (
      { tests, ... }@configuration:
      package:
      let
        overrides = builtins.removeAttrs configuration [ "tests" ];
        configured =
          if overrides == { } then
            package
          else
            package
            // {
              testConfiguration = (package.testConfiguration or { }) // overrides;
              tvp = package.tvp // {
                declaredTestDependencies =
                  (package.tvp.declaredTestDependencies or { })
                  // lib.filterAttrs (name: _: testDeps ? ${name}) overrides;
              };
            };
      in
      tests {
        package = configured;
        inherit lib;
        context =
          package.testContext
          // lib.optionalAttrs (package.testContext ? fixtures) {
            fixtures =
              let
                choices = (configured.tvp.declaredTestDependencies or { }) // (configured.testConfiguration or { });
              in
              package.testContext.fixtures
              // builtins.intersectAttrs package.testContext.fixtures choices
              // lib.optionalAttrs (choices ? locale) { gnuLocale = choices.locale; };
          };
      }
    ) { inherit tests; };
  };
  instantiate =
    {
      version,
      base ? (versionTable.${version}.def.base or context.base),
      deps ? { },
      opts ? { },
    }:
    let
      entry = versionTable.${version};
      selected = api.mkVersions (
        family
        // {
          versionTable = {
            ${version} = prepareEntry (
              entry
              // {
                def = entry.def // {
                  inherit base;
                  deps = entry.def.deps // deps;
                  opts = (entry.def.opts or { }) // opts;
                };
              }
            );
          };
        }
      );
    in
    builtins.head (builtins.attrValues selected);
in
family
