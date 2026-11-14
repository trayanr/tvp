# Pure family/profile/isolation contracts; no realization.
{ lib, tvp }:
let
  steps = import ../../lib/build-steps.nix;
  all = lib.filterAttrs (
    name: _: lib.hasPrefix "libffi_" name || lib.hasPrefix "mpdecimal_" name
  ) tvp.canonical;
  inspect =
    _: p:
    let
      s = p.specification;
      parts = steps.partition s.plan;
      disabled = p.override { doCheck = false; };
      fixture = p.edit (
        old:
        old
        // {
          upstreamSourceLayout = old.upstreamSourceLayout // {
            edits = [ ];
          };
          upstreamCheck = old.upstreamCheck // {
            run = "false # isolated validation control";
          };
        }
      );
      raw = p.tests.upstream.passthru.upstreamExecution;
    in
    assert parts.split;
    assert !(builtins.any (step: lib.hasSuffix ".check" step.name) parts.first);
    assert
      (builtins.elemAt parts.first (builtins.length parts.first - 1)).name
      == "${p.pname}.save-build-tree";
    assert (builtins.head parts.second).name == "output.copy-artifacts";
    assert disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
    assert !(disabled.tests ? upstream);
    assert fixture.artifact.drvPath == p.artifact.drvPath && fixture.drvPath == p.drvPath;
    assert fixture.tests.upstream.passthru.upstreamExecution.drvPath != raw.drvPath;
    assert p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    {
      pass = true;
    };
in
assert builtins.length (builtins.attrNames all) == 25;
lib.mapAttrs inspect all
