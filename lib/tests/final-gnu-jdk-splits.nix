# Source-only scoped contracts. Evaluation never realizes a recipe/test producer.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  gcc = tvp.canonical.gcc_16_2_0;
  glibc = tvp.canonical.glibc_2_39;
  jdk = tvp.canonical.jdk_21_0_13;
  scope = { gcc_16_2_0 = gcc; glibc_2_39 = glibc; jdk_21_0_13 = jdk; };
  plain = builtins.unsafeDiscardStringContext;
  has = needle: value: lib.hasInfix (plain needle) (plain value);
  first = p: (steps.partition p.specification.plan).first;
  second = p: (steps.partition p.specification.plan).second;
  text = plan: lib.concatStringsSep "\n" (map (s: s.run or "") plan);
  runtimeEdit = jdk.editRuntime (r: r // { dlopenDirectories = [ "${jdk.specification.zlib}/lib" ]; });
  scriptEdit = p: p.editSteps (steps.append [{ name = "source.final-control"; run = ": source-final-control"; }]);
  sourceEdit = p: p.edit (s: s // { src = builtins.toFile "source-control" "source-control"; });
  gccClassifier = gcc.edit (s: s // { upstreamClassifier = builtins.toFile "gcc-control-classifier.py" "raise SystemExit(1)\n"; });
  gccUpstream = p: import ../../pkgs/compilers/gcc/tests/upstream-16.2.0.nix { inherit tvp lib; package = p; };
  inventory = tvp.lib.recipeSplits.inventory { canonical = scope; };
  contracts = {
    scopedInventory = builtins.length inventory.rows == 3 && builtins.all (r: r.failure == null) inventory.rows;
    productionOutputs = gcc.outputs == [ "out" ] && glibc.outputs == [ "out" "bin" ] && jdk.outputs == [ "out" ];
    finalEditsReuse = builtins.all (p: p.artifact.drvPath == (scriptEdit p).artifact.drvPath && p.drvPath != (scriptEdit p).drvPath) (builtins.attrValues scope);
    genuineSourceInvalidates = builtins.all (p: p.artifact.drvPath != (sourceEdit p).artifact.drvPath) (builtins.attrValues scope);
    gccFinalizerCodeReuse = let q = gcc.edit (s: s // { finalizerScript = builtins.toFile "final-gcc-control.py" "final-control"; }); in q.artifact.drvPath == gcc.artifact.drvPath && q.drvPath != gcc.drvPath && q.validation.drvPath == gcc.validation.drvPath;
    glibcFinalizerCodeReuse = let q = glibc.edit (s: s // { finalizerScript = builtins.toFile "final-glibc-control.py" "final-control"; }); in q.artifact.drvPath == glibc.artifact.drvPath && q.drvPath != glibc.drvPath;
    jdkAssemblyCodeReuse = let q = jdk.edit (s: s // { assemblyScript = builtins.toFile "packaging-control.py" "packaging-control"; }); in q.artifact.drvPath == jdk.artifact.drvPath && q.drvPath != jdk.drvPath;
    gccRestoreCodeReuse = let q = gcc.edit (s: s // { upstreamRestore = builtins.toFile "restore-control.py" "restore-control"; }); in q.artifact.drvPath == gcc.artifact.drvPath && q.drvPath == gcc.drvPath && q.validation.drvPath != gcc.validation.drvPath;
    jdkRuntimeReuse = runtimeEdit.artifact.drvPath == jdk.artifact.drvPath && runtimeEdit.drvPath != jdk.drvPath;
    jdkShellCompile = (jdk.edit (s: s // { bash = s.coreutils; })).artifact.drvPath != jdk.artifact.drvPath;
    jdkFontCompile = (jdk.edit (s: s // { fontconfig = s.zlib; })).artifact.drvPath != jdk.artifact.drvPath;
    glibcFlagsCompile = (glibc.edit (s: s // { cflags = "-O1"; })).artifact.drvPath != glibc.artifact.drvPath;
    gccPrefixCompile = (gcc.edit (s: s // { configurePrefix = "/tvp/alternate-gcc"; })).artifact.drvPath != gcc.artifact.drvPath;
    overrideEdit = (jdk.override { configurationName = "contract-configuration"; }).drvPath == (jdk.edit (s: s // { configurationName = "contract-configuration"; })).drvPath;
    gccHarnessReuse = let q = gcc.edit (s: s // { fonts = s.coreutils; }); in q.artifact.drvPath == gcc.artifact.drvPath && q.drvPath == gcc.drvPath && q.validation.drvPath != gcc.validation.drvPath;
    gccClassifierReuse = gccClassifier.artifact.drvPath == gcc.artifact.drvPath && gccClassifier.drvPath == gcc.drvPath;
    gccClassifierOnlyU = (gccUpstream gccClassifier).execution.drvPath == gcc.validation.drvPath && (gccUpstream gccClassifier).acceptance.drvPath != gcc.tests.upstream-audit.drvPath;
    gccNoReverseValidation = !has gcc.validation.drvPath (text (first gcc)) && !has "check-gcc" (text (first gcc));
    gccValidationAPI = gcc.validation.drvPath == (gccUpstream gcc).execution.drvPath && !builtins.elem "validation" gcc.outputs;
    gccFactoryRegistration = gcc.tests.upstream-audit.tvp.kind == "owned-test" && gcc.tests.upstream-audit.package.drvPath == gcc.validation.drvPath;
    glibcOutputWidths = builtins.all (n: builtins.stringLength (plain glibc.${n}.outPath) == builtins.stringLength (plain glibc.artifact.${n}.outPath)) glibc.outputs;
    glibcCompleteMap = has "TVP_ARTIFACT_OUTPUTS[out]" (text (second glibc)) && has "TVP_ARTIFACT_OUTPUTS[bin]" (text (second glibc));
    glibcDataInA = has "localedef" (text (first glibc)) && !has "localedef" (text (second glibc)) && !has "localedata" (text (second glibc));
    gccScalar = !has "TVP_ARTIFACT_OUTPUTS" (text (second gcc));
    jdkScalar = !has "TVP_ARTIFACT_OUTPUTS" (text (second jdk));
    jdkAssemblyBoundary = has " images" (text (first jdk)) && has "assemble" (text (second jdk)) && !has "pre-image-rpaths" (text (first jdk));
    ownedFactoryRegistration = builtins.all (p: builtins.all (t: t.tvp.kind == "owned-test") (builtins.attrValues p.tests)) (builtins.attrValues scope);
    completeInstalledFactories = builtins.length (builtins.attrNames jdk.tests) == 9 && builtins.length (builtins.attrNames glibc.tests) > 5 && builtins.length (builtins.attrNames gcc.tests) == 14;
  };
in {
  inherit contracts;
  success = builtins.all (x: x) (builtins.attrValues contracts);
  rows = inventory.rows;
  commands = builtins.mapAttrs (_: p: map (s: s.run or "") p.buildSteps) scope;
  validationCommands = map (s: s.run or "") gcc.validation.buildSteps;
}
