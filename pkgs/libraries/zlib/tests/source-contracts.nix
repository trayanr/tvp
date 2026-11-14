# Pure evaluated shape and isolation contracts. No realization.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  steps = import ../../../../lib/build-steps.nix;
  all = lib.filterAttrs (name: _: lib.hasPrefix "zlib_" name) tvp.canonical;
  live = lib.filterAttrs (_: p: p.tvp.status.level != "broken") all;
  inspect =
    _: p:
    let
      s = p.specification;
      partition = steps.partition s.plan;
      disabled = p.override { doCheck = false; };
      marker = p.editSteps (
        steps.append [
          {
            name = "contract.final-marker";
            run = ''printf marker > "$out/marker"'';
          }
        ]
      );
      runtime = p.editRuntime (r: r // { pager = p.tvp.declaredTestDependencies.runtimeShell; });
      editedTest = p.tests.upstream.editSteps (
        steps.replace "test.compare" (step: step // { run = "printf test-only"; })
      );
    in
    assert partition.split;
    assert !(builtins.any (step: step.name == "zlib.check") partition.first);
    assert lib.hasInfix "libz.so.${s.installedInterface.libraryVersion}"
      (builtins.head (builtins.filter (step: step.name == "zlib.build") partition.first)).run;
    assert lib.hasInfix " all" s.upstreamCheck.run;
    assert
      (builtins.elemAt partition.first (builtins.length partition.first - 1)).name
      == "zlib.save-build-tree";
    assert (builtins.head partition.second).name == "output.copy-artifacts";
    assert disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
    assert !(disabled.tests ? upstream);
    assert marker.artifact.drvPath == p.artifact.drvPath && marker.drvPath != p.drvPath;
    assert runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    assert editedTest.drvPath != p.tests.upstream.drvPath;
    assert p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    {
      pass = true;
      artifact = builtins.unsafeDiscardStringContext p.artifact.drvPath;
      final = builtins.unsafeDiscardStringContext p.drvPath;
    };
in
assert builtins.length (builtins.attrNames all) == 75;
assert builtins.length (builtins.attrNames live) == 65;
lib.mapAttrs inspect live
