# Pure finite source-wave contracts. Evaluating this check realizes nothing.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  names = [
    "alsa-lib_1_2_16_1"
    "freetype_2_15_0"
    "fontconfig_2_18_3"
    "libcups_2_4_20"
    "libdns_sd_2881_120_11"
    "xorgproto_2026_1"
    "libxau_1_0_12"
    "libxdmcp_1_1_5"
    "xcb-proto_1_17_0"
    "libxcb_1_17_0"
    "libx11_1_8_14"
    "xtrans_1_6_0"
    "libice_1_1_2"
    "libsm_1_2_6"
    "libxext_1_3_7"
    "libxfixes_6_0_2"
    "libxi_1_8_4"
    "libxrandr_1_5_5"
    "libxrender_0_9_13"
    "libxt_1_3_1"
    "libxtst_1_2_6"
  ];
  canonical = lib.genAttrs names (n: tvp.canonical.${n});
  report = tvp.lib.recipeSplits.validate {
    inventory = tvp.lib.recipeSplits.inventory { inherit canonical; };
    strict = true;
  };
  perRow =
    p:
    let
      d = p.specification;
      parts = steps.partition p.buildSteps;
      suffix = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "split.final-control";
            run = "true";
          }
        ]
      );
      runtime = p.editRuntime (r: r // { libraries = (r.libraries or [ ]) ++ [ d.coreutils ]; });
      source = p.override { src = builtins.toFile "jdk-source-control" "source"; };
      compiler = p.edit (
        s:
        s
        // {
          base = s.base.override {
            compiler = s.base.compiler // {
              outPath = "/nix/store/00000000000000000000000000000000-compiler-control";
            };
          };
        }
      );
      build = p.edit (
        s:
        s
        // {
          environment = s.environment // {
            overrides.values.JDK_BUILD_CONTROL = "selected";
          };
        }
      );
      disabled = if d ? doCheck then p.override { doCheck = false; } else p;
      upstream = p.tests.upstream or null;
      testEdit =
        if upstream == null then
          null
        else
          upstream.editSteps (
            plan:
            plan
            ++ [
              {
                name = "validation.control";
                run = "true";
              }
            ]
          );
    in
    {
      installedBeforeSplit = builtins.any (s: s.name == "${p.pname}.install") parts.first;
      copyFirst = (builtins.head parts.second).name == "output.copy-artifacts";
      equalWidth = builtins.stringLength p.outPath == builtins.stringLength p.artifact.outPath;
      allOutputs =
        p.outputs == p.artifact.outputs
        && builtins.all (n: p.${n}.artifact.drvPath == p.artifact.drvPath) p.outputs;
      noEarlyRepair = builtins.all (s: !(lib.hasPrefix "output." s.name)) parts.first;
      isolatedChecks = !(builtins.any (s: s.name == "${p.pname}.check") parts.first);
      finalizerReuse = suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
      runtimeReuse =
        runtime.artifact.drvPath == p.artifact.drvPath
        && (
          if builtins.any (s: s.name == "output.rpaths") parts.second then
            runtime.drvPath != p.drvPath
          else
            runtime.drvPath == p.drvPath
        );
      sourceInvalidates = source.artifact.drvPath != p.artifact.drvPath;
      compilerInvalidates = compiler.artifact.drvPath != p.artifact.drvPath;
      environmentInvalidates = build.artifact.drvPath != p.artifact.drvPath;
      testGuardReuse = disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
      registeredOwnedTests =
        p.tests != { } && builtins.all (t: t.tvp.kind == "owned-test") (builtins.attrValues p.tests);
      testEditIndependent = upstream == null || testEdit.drvPath != upstream.drvPath;
      validationReusesProduction =
        upstream == null
        || (
          suffix.tests.upstream.drvPath == upstream.drvPath
          && runtime.tests.upstream.drvPath == upstream.drvPath
        );
      productionPatchInvalidates =
        p.pname != "libcups"
        ||
          (p.override { patches = [ (builtins.toFile "cups-production-control.patch" "control") ]; })
          .artifact.drvPath != p.artifact.drvPath;
      testPatchReuse =
        p.pname != "libcups" || (p.override { patches = [ ]; }).artifact.drvPath == p.artifact.drvPath;
      testsRebound =
        suffix.tests.consumer.package.outPath == suffix.outPath
        && suffix.tests.consumer.drvPath != p.tests.consumer.drvPath;
      upstreamDoesNotConsumeFinal =
        upstream == null || !(builtins.elem p.outPath (map toString upstream.buildStepRunner.inputs));
    };
  rows = builtins.mapAttrs (_: perRow) canonical;
  failures = lib.filterAttrs (_: row: !(builtins.all (x: x) (builtins.attrValues row))) rows;
  retained = tvp.variants.build-steps.fontconfig_2_18_3;
  retainedRuntime = retained.editRuntime (r: r // { libraries = [ pkgs.expat ]; });
  contracts = {
    inherit rows;
    scopedCompliant = report.success && report.counts.compliant == 21;
    retainedDebt =
      !(steps.partition retained.buildSteps).split
      && !(retained ? artifact)
      && retainedRuntime.drvPath != retained.drvPath;
  };
in
assert failures == { } || throw "JDK support split contracts: ${builtins.toJSON failures}";
assert contracts.scopedCompliant && contracts.retainedDebt;
(tvp.canonical.xorgproto_2026_1.testContext.mkTest {
  package = tvp.canonical.xorgproto_2026_1;
  name = "jdk-support-splits";
  tools = [ tvp.canonical.xorgproto_2026_1.specification.python ];
  script = ''
    ${tvp.canonical.xorgproto_2026_1.specification.python}/bin/python3 -B ${./jdk-support-relocate.py} ${../../pkgs/libraries/jdk-support-relocate.py} >&2
    printf '%s' '${builtins.toJSON contracts}'
  '';
  expected = builtins.toJSON contracts;
})
// {
  inherit contracts report;
}
