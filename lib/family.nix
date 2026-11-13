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
  constructor = context.builder;
  standardProviders =
    base:
    (base.standardTools or { })
    // {
      bash = base.shell;
      coreutils = base.coreutils;
      binutils = base.compiler.bintools;
    };
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
      { tests }:
      package:
      tests {
        inherit package lib;
        context = package.testContext;
      }
    ) { inherit tests; };
  };
  instantiate =
    {
      version,
      base ? context.base,
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
