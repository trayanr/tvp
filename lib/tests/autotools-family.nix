# Production/test separation across the four complete ordinary tool families.
{
  pkgs,
  recipes,
  tvp,
}:
let
  inherit (pkgs) lib;
  families = [
    "autoconf"
    "automake"
    "libtool"
    "gnu-config"
  ];
  names = builtins.filter (name: builtins.any (family: lib.hasPrefix "${family}_" name) families) (
    builtins.attrNames tvp.canonical
  );
  declaredNames = lib.concatMap (
    family: map (tvp.lib.versions.attrName family) (builtins.attrNames recipes.${family}.versionTable)
  ) families;
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
    # Keep the original inventory as a minimum and include every added release.
    allRows = builtins.length names >= 114 && names == builtins.sort builtins.lessThan declaredNames;
    allSplit = builtins.all (x: x.split) checks;
    allUpstreamIsIndependent = builtins.all (
      x: x.noUpstreamInProduction && x.independentUpstream
    ) checks;
    allTestPoliciesReuseProduction = builtins.all (x: x.testPolicyReusesProduction) checks;
    gnuConfigDateLabel = recipes.gnu-config.versionTable."2026-05-17".def.name == "2026-05-17";
    oldPerlConstraint =
      tvp.canonical.autoconf_2_53.tvp.deps.perl.drvPath == tvp.packages.perl_5_24.drvPath;
  };
  failed = builtins.filter (name: !result.${name}) (builtins.attrNames result);
in
assert failed == [ ] || throw "Autotools family contracts: ${lib.concatStringsSep ", " failed}";
result
