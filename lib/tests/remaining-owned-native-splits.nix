# SOURCE ONLY: exact assigned successful rows, no catalogue/graph traversal.
{ tvp, lib }:
let
  names = [
    "acl_2_3_2" "acl_2_4_0" "attr_2_6_0" "ca-certificates_2026_10_20"
    "curl_8_23_0" "expat_2_9_0" "gdbm_1_26" "gn_20260707" "gradle_9_3_1"
    "isl_0_28" "libffi_3_8_0" "libxcrypt_4_5_2" "libxml2_2_15_4" "libyaml_0_2_5"
    "linux-headers_6_9" "mpdecimal_4_0_1" "openssl_3_6_3" "openssl_4_0_1"
    "patchelf_0_19_2" "pcre2_10_49" "perl_5_44_0" "sqlite_3_53_4" "unzip_6_0" "zip_3_0"
  ];
  selected = lib.genAttrs names (n: tvp.canonical.${n});
  inspect = name: p:
    let
      s = p.specification;
      parts = tvp.builder.steps.partition p.buildSteps;
      source = p.edit (s: s // { src = builtins.toFile "owned-native-source-control" "offline identity control"; });
      finalOnly = p.editSteps (steps: steps ++ [{ name = "contract.final-only"; run = ": final-only"; }]);
      runtime = p.editRuntime (r: r // { libraries = (r.libraries or [ ]) ++ [ s.coreutils ]; });
      validation = p.edit (s: s // { upstreamCheck = s.upstreamCheck // { run = ": changed validation"; }; });
      unchecked = p.override { doCheck = false; };
      buildOnly = p.editSteps (steps: map (step: if step.name == (builtins.head parts.first).name then step // { run = step.run + "\n: source-control"; } else step) steps);
      compilerOnly = p.edit (s: s // { base = s.base.override { compiler = (import ../../bases/source-gnu/tests/probes.nix { }).sentinel; }; });
      copy = builtins.head (builtins.filter (step: step.name == "output.copy-artifacts") parts.second);
      checks = {
        scalarOutput = p.outputs == [ "out" ];
        scalarTransport = !(lib.hasInfix "TVP_ARTIFACT_OUTPUTS" copy.run) && lib.hasInfix "TVP_ARTIFACT_ROOT" copy.run;
        copiedFirst = (builtins.head parts.second).name == "output.copy-artifacts";
        finalEditReusesArtifact = finalOnly.artifact.drvPath == p.artifact.drvPath && finalOnly.drvPath != p.drvPath;
        buildCommandInvalidatesArtifact = buildOnly.artifact.drvPath != p.artifact.drvPath;
        sourceInvalidatesArtifact = source.artifact.drvPath != p.artifact.drvPath;
        overrideIdentity = (p.override { }).drvPath == p.drvPath;
        editIdentity = (p.edit (s: s)).drvPath == p.drvPath;
        runtimeIdentity = (p.editRuntime (r: r)).drvPath == p.drvPath;
        noUpstreamInProduction = builtins.all (step: !(lib.hasSuffix ".check" step.name) && !(lib.hasInfix ".test-" step.name)) parts.first;
      } // lib.optionalAttrs (!(builtins.elem name [ "ca-certificates_2026_10_20" "gradle_9_3_1" ])) {
        compilerInvalidatesArtifact = compilerOnly.artifact.drvPath != p.artifact.drvPath;
      } // lib.optionalAttrs (name == "libffi_3_8_0") {
        testProviderReusesProduction = let edited = p.override { dejagnu = s.coreutils; }; in edited.artifact.drvPath == p.artifact.drvPath && edited.drvPath == p.drvPath;
      } // lib.optionalAttrs (s ? upstreamPlan) {
        registered = p.tests ? upstream;
        rawProducer = p.tests.upstream.passthru.upstreamExecution.specification.validationRole == "upstream-execution";
        validationEditsReuseProduction = validation.artifact.drvPath == p.artifact.drvPath && validation.drvPath == p.drvPath;
        validationEditsChangeRaw = validation.tests.upstream.passthru.upstreamExecution.drvPath != p.tests.upstream.passthru.upstreamExecution.drvPath;
        doCheckReusesProduction = unchecked.artifact.drvPath == p.artifact.drvPath && unchecked.drvPath == p.drvPath;
        doCheckUnregisters = !(unchecked.tests ? upstream);
      } // lib.optionalAttrs (s ? runtime && s.runtime ? libraries && !(builtins.elem name [ "linux-headers_6_9" "gradle_9_3_1" ])) {
        runtimeLibrariesReuseArtifact = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
      } // lib.optionalAttrs (s ? artifactName) {
        equalWidth = builtins.stringLength p.artifact.outPath == builtins.stringLength p.outPath;
      } // lib.optionalAttrs (s ? finalizeHelper) {
        finalizerEditReusesArtifact = (p.edit (s: s // { finalizeHelper = builtins.toFile "finalizer-control.py" "# identity control"; })).artifact.drvPath == p.artifact.drvPath;
      };
    in {
      inherit checks;
      passed = builtins.all (x: x) (builtins.attrValues checks);
      outputs = p.outputs;
      producer = p.drvPath;
      artifact = p.artifact.drvPath;
      canonicalCopyCommand = copy.run;
      # Real recipe-selected command, with a retained host provider for offline
      # byte fixtures. Never realize an unavailable canonical Coreutils producer.
      copyCommand = (builtins.head (builtins.filter (step: step.name == "output.copy-artifacts")
        (p.override { coreutils = tvp.canonical.acl_2_3_2.specification.coreutils; }).buildSteps)).run;
      commands = map (step: { inherit (step) name run; }) (tvp.builder.steps.active (parts.first ++ parts.second))
        ++ lib.optionals (s ? upstreamPlan) (map (step: { inherit (step) name run; }) (tvp.builder.steps.active s.upstreamPlan) ++ [{ inherit (s.upstreamCheck) name run; }]);
      fixtureCopyProvider = toString tvp.canonical.acl_2_3_2.specification.coreutils;
      rawCommands = if s ? upstreamPlan then map (step: { inherit (step) name run; }) p.tests.upstream.passthru.upstreamExecution.buildSteps else [ ];
      tests = builtins.mapAttrs (_: t: t.drvPath) p.tests;
    };
  rows = builtins.mapAttrs inspect selected;
in {
  inherit rows;
  inventory = tvp.lib.recipeSplits.inventory { canonical = selected; };
  success = builtins.all (r: r.passed) (builtins.attrValues rows);
  sourceOnly = true;
  full = false;
  machineReady = false;
  mergeEligible = false;
}
