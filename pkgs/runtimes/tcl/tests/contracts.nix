# Pure family and edit contracts. Evaluating this file builds/executes nothing.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  names = builtins.filter (n: lib.hasPrefix "tcl_" n) (builtins.attrNames tvp.canonical);
  family = lib.genAttrs names (n: tvp.canonical.${n});
  probe = builtins.toFile "tcl-edit-probe" "probe";
  toolProbe = tvp.packages.coreutils.override { version = "tcl-tool-probe"; };
  same = a: b: a.artifact.drvPath == b.artifact.drvPath && a.drvPath == b.drvPath;
  every = f: builtins.all f (builtins.attrValues family);
  focusedNames = [
    "tcl_8_0_2"
    "tcl_8_1_0"
    "tcl_8_5_19"
    "tcl_8_6_0"
    "tcl_8_6_18"
    "tcl_9_0_0"
    "tcl_9_1_0"
  ];
  focus = f: builtins.all (n: f family.${n}) focusedNames;
  runtimeEdit = p: p.editRuntime (r: r // { dlopenDirectories = [ "/tcl-runtime-probe" ]; });
  sourceEdit = p: p.override { src = probe; };
  toolEdit =
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
  native = [
    family.tcl_8_6_18
    family.tcl_9_1_0
  ];
  testEdit =
    field: p:
    p.edit (
      s:
      s
      // {
        ${field} =
          if field == "testPatches" then
            [ probe ]
          else if field == "upstreamExpected" then
            "edited"
          else
            probe;
      }
    );
  testsRebound = p: builtins.all (t: t.package.outPath == p.outPath) (builtins.attrValues p.tests);
  split = tvp.lib.recipeSplits.inventory { canonical = family; };
in
{
  counts = {
    total = builtins.length names;
    owned = builtins.length (builtins.filter (r: r.constructor == "owned") split.rows);
    compliant = builtins.length (builtins.filter (r: r.compliant) split.rows);
  };
  rows = split.rows;
  controls = {
    exactCount = builtins.length names == 82;
    allSplit = every (p: (steps.partition p.buildSteps).split && p ? artifact);
    installedBeforeSplit = every (
      p: builtins.elem "tcl.install" (map (s: s.name) (steps.partition p.buildSteps).first)
    );
    finalizationAfterSplit = every (
      p: builtins.elem "tcl.relocate-prefix" (map (s: s.name) (steps.partition p.buildSteps).second)
    );
    noProductionExecution = every (
      p:
      builtins.all (
        s:
        !(builtins.elem s.name [
          "tcl.check"
          "tcl.check-packages"
        ])
      ) p.buildSteps
    );
    allOutputs = every (
      p:
      p.outputs == [ "out" ] && p.out.drvPath == p.drvPath && (builtins.head p.all).drvPath == p.drvPath
    );
    equalWidth = every (p: builtins.stringLength p.artifact.outPath == builtins.stringLength p.outPath);
    sourceInvalidates = focus (
      p: (sourceEdit p).artifact.drvPath != p.artifact.drvPath && (sourceEdit p).drvPath != p.drvPath
    );
    sourceRebound = focus (p: testsRebound (sourceEdit p));
    runtimeReusesArtifact = focus (
      p: (runtimeEdit p).artifact.drvPath == p.artifact.drvPath && (runtimeEdit p).drvPath != p.drvPath
    );
    runtimeRebound = focus (p: testsRebound (runtimeEdit p));
    finalToolReusesArtifact = focus (
      p: (toolEdit p).artifact.drvPath == p.artifact.drvPath && (toolEdit p).drvPath != p.drvPath
    );
    runtimeShellReusesArtifact = focus (
      p:
      let
        e = p.editRuntime (r: r // { shell = toolProbe; });
      in
      e.artifact.drvPath == p.artifact.drvPath && e.drvPath != p.drvPath
    );
    runtimeProviderReusesArtifact =
      builtins.all
        (
          p:
          let
            e = p.editRuntime (r: r // { zlib = tvp.packages.zlib_1_3_1; });
          in
          e.artifact.drvPath == p.artifact.drvPath
          && e.drvPath != p.drvPath
          && e.tvp.deps.zlib.drvPath == tvp.packages.zlib_1_3_1.drvPath
          && testsRebound e
        )
        [
          family.tcl_8_6_0
          family.tcl_8_6_18
          family.tcl_9_1_0
        ];
    productionProviderInvalidates =
      builtins.all
        (
          p:
          let
            e = p.override { zlib = tvp.packages.zlib_1_3_1; };
          in
          e.artifact.drvPath != p.artifact.drvPath
          && e.tvp.deps.zlib.drvPath == tvp.packages.zlib_1_3_1.drvPath
          && testsRebound e
        )
        [
          family.tcl_8_6_0
          family.tcl_8_6_18
          family.tcl_9_1_0
        ];
    testPkgConfigIsolated = focus (
      p:
      let
        e = p.edit (s: s // { testPkgConfig = toolProbe; });
      in
      same e p && (!(p.tests ? pkg-config) || e.tests.pkg-config.drvPath != p.tests.pkg-config.drvPath)
    );
    toolMetadata = focus (p: (toolEdit p).tvp.deps.binutils.drvPath == toolProbe.drvPath);
    oldApi =
      !family.tcl_8_0_2.tvp.features.are
      && !family.tcl_8_5_15.tvp.features.pkgConfig
      && family.tcl_8_5_16.tvp.features.pkgConfig;
    oldNoZlib = !(family.tcl_8_5_19.tvp.deps ? zlib);
    dialect =
      family.tcl_8_0_2.specification.cStandard == "gnu89" && family.tcl_8_6_0.specification.linkUnwinder;
    pkgConfigVersion = family.tcl_8_6_0.tvp.pkgConfigVersion == "8.6";
    nativeTestIsolation = builtins.all (
      p:
      builtins.all
        (
          field:
          same (testEdit field p) p && (testEdit field p).tests.upstream.drvPath != p.tests.upstream.drvPath
        )
        [
          "testSource"
          "testPatches"
          "testShell"
          "testPython"
          "testPrepare"
          "testRunner"
          "upstreamExpected"
        ]
    ) native;
    doCheckTestOnly = builtins.all (
      p:
      let
        off = p.override { doCheck = false; };
      in
      same off p && !(off.tests ? upstream)
    ) native;
    allTestsEvaluate = every (
      p: builtins.all (t: builtins.isString t.drvPath) (builtins.attrValues p.tests)
    );
  };
}
