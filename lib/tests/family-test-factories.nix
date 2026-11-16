# Every family shares the owned test factory; caller configuration is test-only.
{
  pkgs,
  tvp,
  recipes,
}:
let
  cases = {
    zlib = "1.2.10";
    zstd = "1.5.6";
    autoconf = "2.69";
    automake = "1.12";
    libtool = "2.4.7";
    bison = "3.8.1";
    flex = "2.6.3";
    texinfo = "7.1";
    gnutar = "1.32";
    zip = "3.0";
    unzip = "6.0";
  };
  identities = builtins.mapAttrs (_: test: test.drvPath);
  contracts = builtins.mapAttrs (
    name: version:
    let
      family = recipes.${name};
      p = family.instantiate { inherit version; };
      factory = family.extraArgs.mkTests;
      rebound = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "factory.final-control";
            run = ":";
          }
        ]
      );
      selected =
        (factory.override {
          helpers = "selected-helpers";
          tests = { package, context, ... }: {
            options = package.testConfiguration;
            probe = context.mkTest {
              inherit package;
              name = "selected-factory";
              script = "printf selected";
              expected = "selected";
            };
          };
        })
          rebound;
      fixtureSelection =
        (factory.override {
          sentinel = rebound;
          alternateSource = rebound;
          locale = rebound;
          tests = { context, ... }: {
            sentinel = context.fixtures.sentinel.drvPath;
            alternate = context.fixtures.alternateSource.drvPath;
            locale = context.fixtures.gnuLocale.drvPath;
          };
        })
          p;
    in
    {
      owned = p ? artifact && p ? testContext && !(p ? overrideAttrs);
      noCapturedRecipe = !(family ? constructionRecipe);
      defaultFactory = identities (factory p) == identities p.tests;
      callerConfiguration = selected.options.helpers == "selected-helpers";
      fixtureSentinelOverride = fixtureSelection.sentinel == rebound.drvPath;
      fixtureSourceOverride = fixtureSelection.alternate == rebound.drvPath;
      fixtureLocaleOverride = fixtureSelection.locale == rebound.drvPath;
      effectivePackage = selected.probe.package.drvPath == rebound.drvPath;
      effectiveBase =
        selected.probe.specification.base.compiler.drvPath == rebound.specification.base.compiler.drvPath;
      finalOnlyReuse = rebound.artifact.drvPath == p.artifact.drvPath && rebound.drvPath != p.drvPath;
    }
  ) cases;
  failed = builtins.filter (
    name: !(builtins.all (passed: passed) (builtins.attrValues contracts.${name}))
  ) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Family test factory contracts failed: ${builtins.toJSON failed}";
pkgs.writeText "tvp-family-test-factory-contracts" (builtins.toJSON contracts)
