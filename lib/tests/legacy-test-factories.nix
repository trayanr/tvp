# A public compatibility factory must keep both its default and caller-selected
# test builders. These probes evaluate constructors; no legacy package is built.
{
  pkgs,
  tvp,
  recipes,
}:
let
  selected = {
    inherit (pkgs) lib;
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
      recipe = recipes.${family};
      construction = recipe.constructionRecipe;
      # Ordinary canonical releases may already be owned. Exercise the retained
      # procedure through the public fallback rather than assume it is canonical.
      package = (tvp.lib.packages.mkVersions construction).${attr};
      retained = construction.extraArgs.mkTests;
      publicFactory = recipe.extraArgs.mkTests;
      publicSelected = (publicFactory.override { pkgs = selected; }) package;
      retainedSelected = (retained.override { pkgs = selected; }) package;
      variant =
        (tvp.lib.packages.mkVariants (
          construction
          // {
            extraArgs.mkTests = publicFactory;
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
      retainedControl =
        if family == "zstd" then
          builtins.isFunction retained
        else
          retainedSelected.version.selectedTestPkgs or false;
      defaultIdentities = identities (publicFactory package) == identities (retained package);
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
  archiveProbe =
    family: counterpart:
    let
      retained = import (../../pkgs/build-tools + "/${family}/legacy.nix") { inherit pkgs tvp; };
      other = import (../../pkgs/build-tools + "/${counterpart}/legacy.nix") { inherit pkgs tvp; };
      package = retained.aliases.${family};
      original = retained.publicArgs.extraArgs.mkTests;
      publicFactory = recipes.${family}.extraArgs.mkTests;
      fallback = publicFactory package;
      requested = {
        ${counterpart} = tvp.packages.${counterpart};
      };
      hasCounterpart =
        test: dependency: builtins.any (input: input.outPath == dependency.outPath) test.nativeBuildInputs;
    in
    {
      legacy = !(package ? testContext);
      retainedCounterpart = hasCounterpart package.tests.roundtrip other.aliases.${counterpart};
      fallbackCounterpart = hasCounterpart fallback.roundtrip other.aliases.${counterpart};
      defaultIdentities = identities fallback == identities (original package);
      requestedBuilder =
        ((publicFactory.override { pkgs = selected; }) package).version.selectedTestPkgs or false;
      retainedControl =
        ((original.override { pkgs = selected; }) package).version.selectedTestPkgs or false;
      requestedCounterpart = hasCounterpart ((publicFactory.override requested) package)
        .roundtrip tvp.packages.${counterpart};
      retainedRequestedCounterpart = hasCounterpart ((original.override requested) package)
        .roundtrip tvp.packages.${counterpart};
    };
  contracts = {
    zlib = probe "zlib" "1.2.10";
    zstd = probe "zstd" "1.5.6";
    autoconf = probe "autoconf" "2.69";
    automake = probe "automake" "1.12";
    libtool = probe "libtool" "2.4.7";
    bison = probe "bison" "3.8.1";
    flex = probe "flex" "2.6.3";
    texinfo = texinfoProbe;
    zip = archiveProbe "zip" "unzip";
    unzip = archiveProbe "unzip" "zip";
  };
  failed = builtins.filter (
    family: !(builtins.all (x: x) (builtins.attrValues contracts.${family}))
  ) (builtins.attrNames contracts);
in
assert failed == [ ] || throw "Legacy test factory contracts failed: ${builtins.toJSON failed}";
pkgs.writeText "tvp-legacy-test-factory-contracts" (builtins.toJSON contracts)
