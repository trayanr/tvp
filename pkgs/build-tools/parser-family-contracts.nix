# Evaluated interface/split/isolation checks for the completed parser families.
{ tvp, lib }:
let
  steps = import ../../lib/build-steps.nix;
  all = lib.filterAttrs (
    name: _: lib.hasPrefix "bison_" name || lib.hasPrefix "flex_" name
  ) tvp.canonical;
  inspect =
    _: p:
    let
      s = p.specification;
      parts = steps.partition s.plan;
      disabled = p.override { doCheck = false; };
      fixtureEdit = p.edit (
        old:
        old
        // {
          upstreamCheck = old.upstreamCheck // {
            run = "false # isolated fixture control";
          };
        }
      );
      noFixturePatch = if p.pname == "bison" then p.override { upstreamPatches = [ ]; } else p;
      changed = p.tests.upstream.editSteps (
        steps.replace "test.compare" (old: old // { run = "printf test-only"; })
      );
    in
    assert parts.split;
    assert (builtins.head parts.second).name == "output.copy-artifacts";
    assert !(builtins.any (step: builtins.match ".*\.check" step.name != null) parts.first);
    assert
      (builtins.elemAt parts.first (builtins.length parts.first - 1)).name
      == "${p.pname}.save-build-tree";
    assert disabled.artifact.drvPath == p.artifact.drvPath && disabled.drvPath == p.drvPath;
    assert !(disabled.tests ? upstream);
    assert fixtureEdit.artifact.drvPath == p.artifact.drvPath && fixtureEdit.drvPath == p.drvPath;
    assert noFixturePatch.artifact.drvPath == p.artifact.drvPath && noFixturePatch.drvPath == p.drvPath;
    assert changed.drvPath != p.tests.upstream.drvPath;
    assert p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    {
      pass = true;
    };
in
assert builtins.length (builtins.attrNames all) == 15;
lib.mapAttrs inspect all
