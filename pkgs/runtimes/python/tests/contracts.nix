# Pure whole-public-cohort contracts: no realization or test execution.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  names =
    map (v: "python_${builtins.replaceStrings [ "." ] [ "_" ] v}") [
      "3.5.10"
      "3.6.15"
      "3.7.17"
      "3.8.20"
      "3.9.25"
      "3.10.22"
      "3.11.18"
      "3.12.16"
      "3.13.18"
      "3.14.10"
      "3.15.2"
    ]
    ++ [
      "python-build_3_12_5"
      "python-minimal_3_12_5"
    ];
  family = lib.genAttrs names (n: tvp.canonical.${n});
  every = f: builtins.all f (builtins.attrValues family);
  probe = builtins.toFile "python-source-probe" "probe";
  toolProbe = tvp.packages.coreutils.override { version = "python-tool-probe"; };
  split = p: steps.partition p.buildSteps;
  sourceEdit = p: p.override { src = probe; };
  runtimeEdit = p: p.editRuntime (r: r // { dlopenDirectories = [ "/python-runtime-probe" ]; });
  shellEdit = p: p.editRuntime (r: r // { shell = toolProbe; });
  toolsEdit =
    p:
    p.edit (
      s:
      s
      // {
        tools = s.tools // {
          binutils = toolProbe;
        };
      }
    );
  compileToolEdit =
    p:
    p.edit (
      s:
      s
      // {
        tools = s.tools // {
          gnumake = toolProbe;
        };
      }
    );
  disabledEdit = p: p.override { disabledModules = p.tvp.disabledModules ++ [ "_tvp_probe" ]; };
  rebound = p: builtins.all (t: t.package.outPath == p.outPath) (builtins.attrValues p.tests);
  finalOnly =
    edit: p:
    let
      e = edit p;
    in
    e.artifact.drvPath == p.artifact.drvPath && e.drvPath != p.drvPath && rebound e;
  production =
    edit: p:
    let
      e = edit p;
    in
    e.artifact.drvPath != p.artifact.drvPath && e.drvPath != p.drvPath && rebound e;
  recipes = (import ../../../../pkgs { inherit pkgs tvp; }).recipes;
  testsVia =
    p:
    let
      f = recipes.${p.pname}.extraArgs.mkTests;
    in
    builtins.attrNames (f p) == builtins.attrNames p.tests
    && builtins.attrNames ((f.override { inherit pkgs; }) p) == builtins.attrNames p.tests;
  full = p: p.pname == "python";
  allFull = f: builtins.all f (builtins.filter full (builtins.attrValues family));
  baseline = builtins.fromJSON (builtins.readFile ../../../../audits/split-baseline.json);
in
{
  rows = (tvp.lib.recipeSplits.inventory { canonical = family; }).rows;
  controls = {
    exactCount = builtins.length names == 13;
    allSplit = every (p: (split p).split && p ? artifact);
    equalWidth = every (p: builtins.stringLength p.outPath == builtins.stringLength p.artifact.outPath);
    installBeforeSplit = every (p: builtins.elem "python.install" (map (s: s.name) (split p).first));
    finalizationAfterSplit = every (
      p:
      builtins.elem "output.copy-artifacts" (map (s: s.name) (split p).second)
      && builtins.elem "output.development" (map (s: s.name) (split p).second)
    );
    noEarlyRepair = every (p: builtins.all (s: !(lib.hasPrefix "output." s.name)) (split p).first);
    noProductionTests = every (
      p:
      builtins.all (
        s:
        !(builtins.elem s.name [
          "python.check"
          "python.upstream"
          "python.installed-profile"
        ])
      ) p.buildSteps
    );
    allOutputs = every (
      p:
      p.outputs == [ "out" ]
      && p.out.drvPath == p.drvPath
      && (builtins.head p.all).drvPath == p.drvPath
      && rebound p.out
      && rebound (builtins.head p.all)
    );
    sourceInvalidates = every (production sourceEdit);
    compileToolInvalidates = every (production compileToolEdit);
    disabledModulesInvalidate = every (production disabledEdit);
    runtimeReusesArtifact = every (finalOnly runtimeEdit);
    finalToolReusesArtifact = every (finalOnly toolsEdit);
    runtimeShellReusesArtifact = every (finalOnly shellEdit);
    testDerivations = every (
      p: builtins.all (t: builtins.stringLength t.drvPath > 0) (builtins.attrValues p.tests)
    );
    testFactories = every (p: testsVia p && testsVia p.out && testsVia (builtins.head p.all));
    identityEdits = every (
      p:
      (p.override { }).drvPath == p.drvPath
      && (p.override (_: { })).drvPath == p.drvPath
      && (p.edit (s: s)).drvPath == p.drvPath
      && (p.editRuntime (r: r)).drvPath == p.drvPath
      && (p.editSteps (s: s)).drvPath == p.drvPath
    );
    functionalOverride = every (
      p:
      (p.override (_: {
        src = probe;
      })).drvPath == (sourceEdit p).drvPath
    );
    suiteFeatureBoundaries =
      family.python_3_5_10.tests ? embed-finalize
      && !(family.python_3_5_10.tests ? embed)
      && !(family.python_3_5_10.tests ? subprocess)
      && family.python_3_12_16.tests ? crypt
      && !(family.python_3_13_18.tests ? crypt)
      && family.python_3_14_10.tests ? zstd
      && !(family.python_3_14_10.tests ? decimal-linkage)
      && family.python_3_15_2.tests ? decimal-linkage;
    buildProviderEdit =
      let
        p = family.python-build_3_12_5;
        e = p.editRuntime (r: r // { zlib = toolProbe; });
      in
      e.artifact.drvPath == p.artifact.drvPath
      && e.drvPath != p.drvPath
      && e.tvp.deps.zlib.drvPath == toolProbe.drvPath
      && rebound e;
    buildLibraryEdit =
      let
        p = family.python-build_3_12_5;
        e = p.edit (
          s:
          s
          // {
            libraries = s.libraries // {
              zlib = toolProbe;
            };
          }
        );
      in
      e.artifact.drvPath != p.artifact.drvPath && e.tvp.deps.zlib.drvPath == toolProbe.drvPath;

    dependencyOverride = allFull (
      p:
      let
        e = p.override { zlib = toolProbe; };
      in
      e.artifact.drvPath != p.artifact.drvPath
      && e.tvp.deps.zlib.drvPath == toolProbe.drvPath
      && rebound e
    );
    effectiveLibraryEdit = allFull (
      p:
      let
        e = p.edit (
          s:
          s
          // {
            libraries = s.libraries // {
              zlib = toolProbe;
            };
          }
        );
      in
      e.artifact.drvPath != p.artifact.drvPath && e.tvp.deps.zlib.drvPath == toolProbe.drvPath
    );
    runtimeProviderReusesArtifact = allFull (
      p:
      let
        e = p.editRuntime (
          r:
          r
          // {
            providers = r.providers // {
              zlib = toolProbe;
            };
          }
        );
      in
      e.artifact.drvPath == p.artifact.drvPath
      && e.drvPath != p.drvPath
      && e.tvp.deps.zlib.drvPath == toolProbe.drvPath
      && rebound e
    );
    retainedBaselineCount = builtins.length baseline == 181;
    noPythonDebt = builtins.all (r: !(lib.hasPrefix "canonical/python" r.id)) baseline;
    oldOpenSSL =
      builtins.all (n: family.${n}.tvp.deps.openssl.version == tvp.packages.openssl_1_1.version)
        [
          "python_3_5_10"
          "python_3_6_15"
          "python_3_7_17"
        ];
    intermediateOpenSSL =
      builtins.all (n: family.${n}.tvp.deps.openssl.version == tvp.packages.openssl_3_3.version)
        [
          "python_3_8_20"
          "python_3_9_25"
        ];
    matchedCurses =
      family.python_3_5_10.tvp.deps.ncurses.drvPath == tvp.packages.ncurses_6_4.drvPath
      &&
        family.python_3_5_10.tvp.deps.readline.tvp.deps.ncurses.drvPath
        == family.python_3_5_10.tvp.deps.ncurses.drvPath;
    cryptBoundary =
      family.python_3_12_16.tvp.deps ? libxcrypt && !(family.python_3_13_18.tvp.deps ? libxcrypt);
    zstdBoundary = !(family.python_3_13_18.tvp.deps ? zstd) && family.python_3_14_10.tvp.deps ? zstd;
    decimalBoundary =
      !(family.python_3_14_10.tvp.deps ? mpdecimal) && family.python_3_15_2.tvp.deps ? mpdecimal;
    reducedBuildProfile =
      family.python-build_3_12_5.tvp.profile == "build-tools"
      && builtins.length family.python-build_3_12_5.specification.environment.libraries == 4
      && !family.python-build_3_12_5.tvp.features.pipInstalled;
    minimalProfile =
      family.python-minimal_3_12_5.tvp.profile == "build"
      && family.python-minimal_3_12_5.specification.environment.libraries == [ ]
      && !family.python-minimal_3_12_5.tvp.features.externalModules;
  };
}
