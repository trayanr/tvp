# Evaluation contracts for the authoring owner; not executed by this candidate.
{ tvp, lib }:
let
  names = [
    "acl_2_3_0"
    "acl_2_3_1"
    "acl_2_3_2"
    "acl_2_4_0"
  ];
  selected = lib.genAttrs names (name: tvp.canonical.${name});
  earlier = tvp.bases.gcc_13.full;
  underlyingDriver =
    driver: if driver ? underlyingDriver then underlyingDriver driver.underlyingDriver else driver;
  expected = {
    "2.3.0" = {
      libraryFile = "libacl.so.1.1.230";
      runtimeAttr = true;
      propagateAttr = true;
    };
    "2.3.1" = {
      libraryFile = "libacl.so.1.1.2301";
      runtimeAttr = true;
      propagateAttr = true;
    };
    "2.3.2" = {
      libraryFile = "libacl.so.1.1.2302";
      runtimeAttr = true;
      propagateAttr = false;
    };
    "2.4.0" = {
      libraryFile = "libacl.so.1.2.2400";
      runtimeAttr = false;
      propagateAttr = false;
    };
  };
  rows = lib.mapAttrs (
    _: p:
    let
      s = p.specification;
      unchecked = p.override { doCheck = false; };
      changedU = p.edit (
        spec:
        spec
        // {
          upstreamCheck = spec.upstreamCheck // {
            run = ": changed U policy";
          };
        }
      );
      runtime = p.editRuntime (r: r // { libraries = [ ]; });
      stepNames = map (step: step.name) p.buildSteps;
      historical = builtins.elem p.version [
        "2.3.0"
        "2.3.1"
      ];
    in
    {
      exactInterface = s.installedInterface == expected.${p.version};
      attrProvider = s.attr.drvPath == tvp.packages.attr_2.drvPath;
      selectedEarlierCompiler = !historical || s.base.compiler.outPath == earlier.compiler.outPath;
      selectedEarlierLibc = !historical || s.base.compiler.libc.outPath == earlier.compiler.libc.outPath;
      selectedEarlierBinutils =
        !historical || s.base.compiler.bintools.outPath == earlier.compiler.bintools.outPath;
      hardeningPreserved =
        !historical || s.base.compiler.defaultHardeningFlags == earlier.compiler.defaultHardeningFlags;
      checkpointBeforeSplit = builtins.elem "acl.save-build-tree" stepNames;
      hasUpstream = p.tests ? upstream;
      historicalHeadersNotClaimedIsolated = !historical || !(p.tests ? isolated-discovery);
      isolatedInterfacesRetainControl = historical || p.tests ? isolated-discovery;
      doCheckDoesNotInvalidateA = unchecked.artifact.drvPath == p.artifact.drvPath;
      doCheckDoesNotInvalidateF = unchecked.drvPath == p.drvPath;
      upstreamDoesNotInvalidateA = changedU.artifact.drvPath == p.artifact.drvPath;
      upstreamDoesNotInvalidateF = changedU.drvPath == p.drvPath;
      runtimeDoesNotInvalidateA = runtime.artifact.drvPath == p.artifact.drvPath;
    }
  ) selected;
  construction = {
    compilerVersion = earlier.compiler.version == "13.3.0";
    sourceOwned =
      !(earlier ? stdenv) && (underlyingDriver earlier.compiler).tvp.deps.compiler ? artifact;
    sourceBase = earlier.construction.previous == tvp.bases.gcc_16.full.name;
  };
  failed = lib.filterAttrs (_: checks: !(builtins.all (x: x) (builtins.attrValues checks))) (
    rows // { inherit construction; }
  );
in
{
  inherit rows construction failed;
  success = failed == { };
}
