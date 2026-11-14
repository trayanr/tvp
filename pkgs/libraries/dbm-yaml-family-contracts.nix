{ lib, tvp }:
let
  steps = import ../../lib/build-steps.nix;
  all = lib.filterAttrs (n: _: lib.hasPrefix "gdbm_" n || lib.hasPrefix "libyaml_" n) tvp.canonical;
  inspect =
    _: p:
    let
      s = p.specification;
      parts = steps.partition p.buildSteps;
      disabled = p.override { doCheck = false; };
      changed = p.edit (
        x:
        x
        // {
          upstreamCheck = x.upstreamCheck // {
            run = "false # isolated upstream contract";
          };
        }
      );
    in
    assert parts.split;
    assert !(builtins.any (x: lib.hasSuffix ".check" x.name) parts.first);
    assert (builtins.head parts.second).name == "output.copy-artifacts";
    assert disabled.drvPath == p.drvPath && disabled.artifact.drvPath == p.artifact.drvPath;
    assert !(disabled.tests ? upstream);
    assert
      !(s ? upstreamPlan)
      || (
        changed.artifact.drvPath == p.artifact.drvPath
        && changed.drvPath == p.drvPath
        &&
          changed.tests.upstream.passthru.upstreamExecution.drvPath
          != p.tests.upstream.passthru.upstreamExecution.drvPath
        && p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath
      );
    assert s ? upstreamPlan || s ? upstreamUnavailable;
    assert
      p.pname != "libyaml"
      || (
        !(builtins.elem "config" s.sourceLayout.selections)
        && !(builtins.elem "config/test-driver" s.sourceLayout.selections)
        &&
          map (step: step.name) p.tests.upstream.specification.validation.execution.buildSteps == [
            "upstream.initialize"
            "libyaml.restore-build-tree"
            "libyaml.upstream-frontends"
            "upstream.capture"
          ]
      );
    {
      pass = true;
      inherit (p) version;
    };
in
assert builtins.length (builtins.attrNames all) == 39;
lib.mapAttrs inspect all
