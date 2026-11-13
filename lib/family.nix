# Ordinary family defaults; only declared procedure arguments are supplied.
{
  lib,
  api,
  defaultContext ? null,
}:
{
  pname,
  defs,
  releases,
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
    supplied:
    let
      base = supplied.base or context.base;
    in
    context.helpers
    // standardProviders base
    // {
      inherit base;
    };
  definitions = api.mkDefs (
    lib.mapAttrs (
      _: def:
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
      }
    ) defs
  );
  versionTable = api.mkTable (releases {
    defs = definitions;
  });
  family = {
    inherit
      pname
      versionTable
      source
      packageMeta
      testDeps
      ;
    infra = {
      inherit lib;
    };
    argumentDefaults =
      supplied:
      # The actual procedure filters standard inputs; no PATH discovery.
      defaults supplied;
    extraArgs.mkTests = lib.makeOverridable (
      { tests }:
      package:
      tests {
        inherit package lib;
        context = package.testContext;
      }
    ) { inherit tests; };
  };
  canonical = api.mkVersions family;
in
{
  inherit canonical;
  recipes.${pname} = family;
  aliases = api.mkAliases { inherit pname versionTable canonical; };
}
