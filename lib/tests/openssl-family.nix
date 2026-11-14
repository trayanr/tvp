# Bounded source contracts only; the candidate did not evaluate this module.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/libraries/openssl { inherit pkgs tvp; };
  table = family.recipes.openssl.versionTable;
  supported = lib.filterAttrs (_: e: (e.status.level or "ok") != "broken") table;
  inspect =
    v: _:
    let
      p = family.canonical.${tvp.lib.versions.attrName "openssl" v};
      s = p.specification;
      parts = tvp.builder.steps.partition p.buildSteps;
      off = p.override { doCheck = false; };
    in
    assert parts.split;
    assert (builtins.head parts.second).name == "output.copy-artifacts";
    assert !(builtins.any (step: lib.hasSuffix ".check" step.name) parts.first);
    assert off.artifact.drvPath == p.artifact.drvPath && off.drvPath == p.drvPath;
    assert !(off.tests ? upstream);
    assert p.mkTests ? override;
    {
      pass = true;
      upstreamIsolated = s ? upstreamIsolation;
    };
in
assert builtins.length (builtins.attrNames table) == 221;
assert builtins.length (builtins.attrNames supported) == 215;
lib.mapAttrs inspect supported
