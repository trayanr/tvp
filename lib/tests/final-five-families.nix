# Pure owner-run authoring controls; no marker producer may be realized.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  modules = {
    perl = import ../../pkgs/runtimes/perl { inherit pkgs tvp; };
    jdk = import ../../pkgs/runtimes/jdk { inherit pkgs tvp; };
    jdk-bootstrap = import ../../pkgs/runtimes/jdk-bootstrap { inherit pkgs tvp; };
    nodejs = import ../../pkgs/runtimes/nodejs { inherit pkgs tvp; };
    glibc = import ../../pkgs/libraries/glibc { inherit pkgs tvp; };
  };
  expected = {
    perl = 10;
    jdk = 1;
    jdk-bootstrap = 1;
    nodejs = 35;
    glibc = 1;
  };
  selected = lib.foldl' (out: name: out // modules.${name}.canonical) { } (
    builtins.attrNames modules
  );
  row =
    p:
    let
      s = p.specification;
      parts = tvp.builder.steps.partition p.buildSteps;
      source = p.override { src = builtins.toFile "final-five-source-control" "never build"; };
      suffix = p.editSteps (
        xs:
        xs
        ++ [
          {
            name = "final-five.suffix-control";
            run = ": final-control";
          }
        ]
      );
      changedBase = s.base.override {
        coreutils = s.base.coreutils // {
          outPath = "/nix/store/00000000000000000000000000000000-final-five-coreutils-control";
        };
      };
      base = p.edit (spec: spec // { base = changedBase; });
    in
    {
      owned = !(p ? overrideAttrs);
      split = parts.split && parts.first != [ ] && parts.second != [ ];
      singleSplit = builtins.length (builtins.filter (s: (s.kind or "") == "split") p.buildSteps) == 1;
      noOp = (p.override { }).drvPath == p.drvPath && (p.edit (s: s)).drvPath == p.drvPath;
      sourceChangesA = source.artifact.drvPath != p.artifact.drvPath;
      suffixReusesA = suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
      baseCoreutilsRebinds = base.specification.coreutils.outPath == changedBase.coreutils.outPath;
      hostCompiler = s.base.compiler.drvPath == tvp.bases.gcc_16.full.compiler.drvPath;
      versionTest = p.tests ? version;
      reboundTest = suffix.tests.version.package.drvPath == suffix.drvPath;
    };
  rows = lib.mapAttrs (_: row) selected;
  families = lib.mapAttrs (
    name: module:
    let
      recipe = module.recipes.${name};
      versions = builtins.attrNames recipe.versionTable;
    in
    {
      count = builtins.length versions == expected.${name};
      ordinary = recipe.authoring.origin == "tvp.lib.packages.mkFamily";
      instantiate = builtins.all (
        v:
        let
          p = module.instantiate { version = v; };
          canonical = module.canonical.${tvp.lib.versions.attrName name v};
        in
        p.drvPath == canonical.drvPath && p.artifact.drvPath == canonical.artifact.drvPath
      ) versions;
      singleFamilyDefinition = !(recipe ? constructionRecipe);
    }
  ) modules;
  perl = modules.perl.canonical;
  node = modules.nodejs.canonical.nodejs_26_13_0;
  jdk = modules.jdk.canonical.jdk_21_0_13;
  seed = modules.jdk-bootstrap.canonical.jdk-bootstrap_21_0_13;
  libc = modules.glibc.canonical.glibc_2_39;
  strict = {
    oldPerlCheckOutsideProduction =
      builtins.all
        (
          p:
          !(builtins.any (step: step.name == "perl.check") p.buildSteps)
          && p.specification ? upstreamPlan
          && p.specification.upstreamCheck.name == "perl.check"
          && p.tests ? upstream
        )
        (
          map (v: perl.${v}) [
            "perl_5_24_4"
            "perl_5_28_3"
            "perl_5_30_3"
            "perl_5_32_1"
            "perl_5_34_3"
            "perl_5_36_3"
            "perl_5_38_5"
            "perl_5_40_5"
            "perl_5_42_3"
          ]
        );
    oldCalendarNonpassesRetained =
      perl.perl_5_24_4.specification.upstreamNonpasses == [ "Time-Local-rolling-century-1970" ]
      && perl.perl_5_28_3.specification.upstreamNonpasses == [ "Time-Local-rolling-century-1970" ];
    perlProductionHasNoPodHelper =
      !(lib.hasInfix "Pod-Html" (builtins.readFile perl.perl_5_36_3.specification.prepareHelper));
    nodeNinjaGeneration = node.specification.ninja.drvPath == tvp.packages.ninja.drvPath;
    nodeRealRustDependency = node.specification.rustc.drvPath == tvp.packages.rustc_1.drvPath;
    nodeRuntimeShell = node.specification.runtimeBash.drvPath == tvp.bases.gcc_16.full.shell.drvPath;
    nodeNamedCallerOverride =
      ((node.mkTests.override { inherit pkgs; }) node).version.package.drvPath == node.drvPath;
    jdkSeedGeneration = jdk.specification.bootJdk.drvPath == seed.drvPath;
    jdkBinarySeedDeclared =
      modules.jdk-bootstrap.recipes.jdk-bootstrap.versionTable."21.0.13".def ? blob;
    jdkModuleAssemblyRetained = builtins.any (
      step: step.name == "jdk.assemble-compiled-products"
    ) jdk.buildSteps;
    libcTwoNamedOutputs =
      libc.outputs == [
        "out"
        "bin"
      ];
    libcTargetRoles =
      libc.specification.gcc.drvPath == tvp.packages.gcc.drvPath
      && libc.specification.binutils.drvPath == tvp.packages.binutils_2.drvPath;
    libcHostTargetDistinct = libc.specification.base.compiler.drvPath != libc.specification.gcc.drvPath;
    libcReboundToolApi = libc ? mkTools;
  };
  success = builtins.all (x: x) (
    lib.concatMap builtins.attrValues (builtins.attrValues rows)
    ++ lib.concatMap builtins.attrValues (builtins.attrValues families)
    ++ builtins.attrValues strict
  );
in
{
  inherit
    rows
    families
    strict
    success
    ;
}
