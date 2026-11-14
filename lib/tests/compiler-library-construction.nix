# Shared procedures on explicit earlier stages; no compiler or test is built.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  bootstrap = import ../../bootstrap { };
  c = import ../../bootstrap/source-consumers.nix { inherit bootstrap; };
  f = import ../../bootstrap/source-full-gcc.nix { inherit bootstrap; };
  libraries = {
    inherit (c) gmp mpfr mpc;
    inherit (f.prerequisites) isl;
  };
  sameProduction = p: q: p.artifact.drvPath == q.artifact.drvPath && p.drvPath == q.drvPath;
  results = {
    allChecksIndependent = builtins.all (
      p:
      !(builtins.any (s: lib.hasSuffix ".check" s.name) p.buildSteps)
      && p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath
    ) (builtins.attrValues libraries);
    checkPolicyReusesProduction = builtins.all (
      p:
      let
        q = p.override { doCheck = false; };
      in
      sameProduction p q && !(q.tests ? upstream)
    ) (builtins.attrValues libraries);
    stageM4 = c.gmp.tvp.deps.m4.drvPath == bootstrap.build-m4.drvPath;
    stageGmp =
      c.mpfr.tvp.deps.gmp.drvPath == c.gmp.drvPath && c.mpc.tvp.deps.gmp.drvPath == c.gmp.drvPath;
    stageMpfr = c.mpc.tvp.deps.mpfr.drvPath == c.mpfr.drvPath;
    stageIsl = f.prerequisites.isl.tvp.deps.gmp.drvPath == f.native.gmp.drvPath;
    earlierCompiler =
      c.gmp.specification.base.compiler.drvPath == c.composition.cc.drvPath
      && c.mpc.specification.base.compiler.drvPath == c.composition.cc.drvPath;
    nativeCompiler = f.prerequisites.isl.specification.base.compiler.drvPath == f.native.driver.drvPath;
    finalDoesNotRunUpstream = !(builtins.any (s: s.name == "isl.check") f.prerequisites.isl.buildSteps);
    driverKeepsProductionInterface = f.driver.bintools.drvPath == f.native.binutils.drvPath;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Compiler library construction: ${lib.concatStringsSep ", " failed}";
results
