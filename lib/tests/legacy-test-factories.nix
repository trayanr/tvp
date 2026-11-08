# A public compatibility factory must keep both its default and caller-selected
# test builders. These probes evaluate constructors; no legacy package is built.
{
  pkgs,
  tvp,
  recipes,
}:
let
  selected = {
    runCommand = name: args: script: { selectedTestPkgs = true; };
    runCommandWith = args: script: {
      selectedTestPkgs = true;
      selectedBase = args.stdenv;
    };
  };
  identities = builtins.mapAttrs (_: test: test.drvPath);
  probe =
    family: version:
    let
      attr = tvp.lib.versions.attrName family version;
      package = tvp.canonical.${attr};
      recipe = recipes.${family};
      retained = recipe.constructionRecipe.extraArgs.mkTests;
      publicSelected = (package.mkTests.override { pkgs = selected; }) package;
      retainedSelected = (retained.override { pkgs = selected; }) package;
      variant =
        (tvp.lib.packages.mkVariants (
          recipe
          // {
            pkgs = pkgs // selected;
            profiles.test-factory = {
              base = tvp.bases.default;
              versions.${version} = { };
            };
          }
        )).test-factory.${attr};
    in
    {
      legacy = !(package ? testContext);
      requestedBuilder = publicSelected.version.selectedTestPkgs or false;
      retainedControl = retainedSelected.version.selectedTestPkgs or false;
      defaultIdentities = identities (package.mkTests package) == identities (retained package);
      variantBuilder = variant.tests.version.selectedTestPkgs or false;
      variantBase = variant.tests.version.selectedBase.drvPath == tvp.bases.default.stdenv.drvPath;
    };
  # Texinfo has only one release. Exercise the public fallback with its
  # retained constructor, including the nonnative/variant factory path.
  texinfoProbe =
    let
      recipe = recipes.texinfo;
      retained = recipe.constructionRecipe;
      package = (tvp.lib.packages.mkVersions retained).texinfo_7_1;
      publicFactory = recipe.extraArgs.mkTests;
      original = retained.extraArgs.mkTests;
      publicSelected = (publicFactory.override { pkgs = selected; }) package;
      retainedSelected = (original.override { pkgs = selected; }) package;
      replay = retained // {
        extraArgs.mkTests = publicFactory;
      };
      variant =
        (tvp.lib.packages.mkVariants (
          replay
          // {
            pkgs = pkgs // selected;
            profiles.test-factory = {
              base = tvp.bases.default;
              versions."7.1" = { };
            };
          }
        )).test-factory.texinfo_7_1;
    in
    {
      legacy = !(package ? testContext);
      requestedBuilder = publicSelected.version.selectedTestPkgs or false;
      retainedControl = retainedSelected.version.selectedTestPkgs or false;
      defaultIdentities = identities (publicFactory package) == identities (original package);
      variantBuilder = variant.tests.version.selectedTestPkgs or false;
      variantBase = variant.tests.version.selectedBase.drvPath == tvp.bases.default.stdenv.drvPath;
    };
  contracts = {
    bison = probe "bison" "3.8.1";
    flex = probe "flex" "2.6.3";
    texinfo = texinfoProbe;
  };
  failed = builtins.filter (
    family: !(builtins.all (x: x) (builtins.attrValues contracts.${family}))
  ) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Legacy test factory contracts failed: ${builtins.toJSON failed}";
pkgs.writeText "tvp-legacy-test-factory-contracts" (builtins.toJSON contracts)
