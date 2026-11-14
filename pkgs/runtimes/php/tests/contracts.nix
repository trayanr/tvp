# Pure whole-family contracts: no production or historical test realization.
{ pkgs, tvp }:
let
  lib = pkgs.lib;
  all = tvp.canonical;
  family = lib.filterAttrs (n: _: lib.hasPrefix "php_" n) all;
  policy = tvp.lib.recipeSplits.inventory { canonical = family; };
  has =
    needle: haystack:
    lib.hasInfix (builtins.unsafeDiscardStringContext needle) (
      builtins.unsafeDiscardStringContext haystack
    );
  step = n: p: builtins.head (builtins.filter (s: s.name == n) p.buildSteps);
  check =
    n: p:
    let
      finalEdit = p.editRuntime (r: r // { dlopenDirectories = [ "${p.outPath}/lib/php" ]; });
      sourceEdit = p.override { src = builtins.toFile "php-source-probe" "probe"; };
      provider = p.specification.openssl.editSteps (
        xs:
        xs
        ++ [
          {
            name = "php.provider-probe";
            run = "true";
          }
        ]
      );
      depEdit = p.edit (s: s // { openssl = provider; });
      testEdit = p.override { testFeatures.passwordApi = false; };
      binding = p.tests.version;
      factory = (p.mkTests.override { inherit pkgs; }) p;
    in
    {
      split = p.artifact.drvPath != p.drvPath;
      finalReuse = finalEdit.artifact.drvPath == p.artifact.drvPath && finalEdit.drvPath != p.drvPath;
      sourceInvalidates = sourceEdit.artifact.drvPath != p.artifact.drvPath;
      providerInvalidates = depEdit.artifact.drvPath != p.artifact.drvPath;
      providerMetadata = depEdit.tvp.deps.openssl.outPath == provider.outPath;
      providerCommand = has provider.outPath (step "php.configure" depEdit).run;
      providerRuntime = has provider.outPath (step "output.rpaths" depEdit).run;
      providerTests = has provider.outPath (step "test.compare" depEdit.tests.openssl-linkage).run;
      testsIsolated = testEdit.drvPath == p.drvPath && testEdit.artifact.drvPath == p.artifact.drvPath;
      rebound = binding.package.outPath == p.outPath && factory.version.package.outPath == p.outPath;
      projections = builtins.all (
        q:
        q.outPath == p.outPath
        && q.artifact.outPath == p.artifact.outPath
        && q.tests.version.package.outPath == p.outPath
      ) ([ p.out ] ++ p.all);
      noop = (p.override { }).drvPath == p.drvPath;
      outputOverride = (p.out.override { }).outPath == p.outPath;
      testNames = builtins.attrNames p.tests;
      runtimeEdit =
        let
          edited = p.editRuntime (
            r: r // { libraries = map (q: if q.pname == provider.pname then provider else q) r.libraries; }
          );
        in
        edited.artifact.drvPath == p.artifact.drvPath
        && edited.tvp.deps.openssl.outPath == provider.outPath
        && has provider.outPath (step "test.compare" edited.tests.openssl-linkage).run
        && edited.tests.openssl-linkage.package.outPath == edited.outPath;
    };
in
{
  inherit policy;
  legacyContext =
    let
      retained = import ../legacy.nix { inherit pkgs tvp; };
      caller = retained.recipes.php.extraArgs.mkTests.override {
        pkgs = pkgs // {
          runCommandWith = _: _: { callerContext = true; };
        };
      };
    in
    (caller retained.canonical.php_5_0_5).version.callerContext;
  contracts = builtins.mapAttrs check family;
}
