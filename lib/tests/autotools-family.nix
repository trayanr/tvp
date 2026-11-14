# Production/test separation across the four complete ordinary tool families.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  names = builtins.filter (
    name:
    builtins.any (prefix: lib.hasPrefix prefix name) [
      "autoconf_"
      "automake_"
      "libtool_"
      "gnu-config_"
    ]
  ) (builtins.attrNames tvp.canonical);
  packages = map (name: tvp.canonical.${name}) names;
  checks = map (
    p:
    let
      noCheck = p.override { doCheck = false; };
    in
    {
      split = builtins.length (builtins.filter (step: (step.kind or "") == "split") p.buildSteps) == 1;
      noUpstreamInProduction =
        !(builtins.any (
          step:
          builtins.elem step.name [
            "${p.pname}.check"
            "${p.pname}.upstream"
          ]
        ) p.buildSteps);
      testPolicyReusesProduction =
        noCheck.artifact.drvPath == p.artifact.drvPath
        && noCheck.drvPath == p.drvPath
        && !(noCheck.tests ? upstream);
      independentUpstream =
        p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    }
  ) packages;
  result = {
    allRows = builtins.length names == 114;
    allSplit = builtins.all (x: x.split) checks;
    allUpstreamIsIndependent = builtins.all (
      x: x.noUpstreamInProduction && x.independentUpstream
    ) checks;
    allTestPoliciesReuseProduction = builtins.all (x: x.testPolicyReusesProduction) checks;
    gnuConfigDateLabel =
      (import ../../pkgs/build-tools/gnu-config { inherit pkgs tvp; })
      .recipes.gnu-config.versionTable."2026-05-17".def.name == "2026-05-17";
    oldPerlConstraint =
      tvp.canonical.autoconf_2_53.tvp.deps.perl.drvPath == tvp.packages.perl_5_24.drvPath;
  };
  failed = builtins.filter (name: !result.${name}) (builtins.attrNames result);
in
assert failed == [ ] || throw "Autotools family contracts: ${lib.concatStringsSep ", " failed}";
result
