# Assemble existing suites without forcing historical tests during latest selection.
{
  pkgs,
  tvp,
  tvpLib,
  canonical,
  packages,
  legacyBases,
  construction,
  variantPackages,
  checks,
}:
let
  allVariantPackages =
    tvpLib.packages.merge (
      pkgs.lib.mapAttrs (
        profile: entries:
        pkgs.lib.mapAttrs' (
          name: package: pkgs.lib.nameValuePair "bootstrap-${profile}-${name}" package
        ) entries
      ) construction.variants
    )
    // variantPackages;

  # Keep this mapping lazy: latest selection must not enumerate historical suites
  # just to find the selected batch. Full coverage retains its existing filter.
  packageTestBatches = builtins.mapAttrs (
    name: pkg:
    (
      if pkg ? testContext then
        pkg.testContext.mkBatch
      else
        args: tvpLib.tests.compatibility.mkBatch (args // { inherit pkgs; })
    )
      {
        inherit name;
        suite = pkg.tests;
      }
  ) canonical;

  testBatchEntries = tvpLib.packages.merge {
    phpExtensions = tvp.php.extensionTests;
    packages = pkgs.lib.filterAttrs (
      name: _:
      let
        pkg = canonical.${name};
      in
      pkg ? tests && pkg.tests != { } && (pkg.tvp.status.level or "ok") != "broken"
    ) packageTestBatches;
    bases = pkgs.lib.mapAttrs' (
      name: base:
      pkgs.lib.nameValuePair "base-${name}" (
        tvpLib.tests.compatibility.mkBatch {
          inherit pkgs;
          name = "base-${name}";
          suite = base.tests;
        }
      )
    ) (pkgs.lib.filterAttrs (name: base: base.name == name) legacyBases);
    bootstrapBases = pkgs.lib.mapAttrs' (
      name: base:
      pkgs.lib.nameValuePair "bootstrap-base-${name}" (
        tvpLib.tests.compatibility.mkBatch {
          inherit pkgs;
          name = "bootstrap-base-${name}";
          suite = base.tests;
        }
      )
    ) construction.bases;
    variants = pkgs.lib.mapAttrs (
      name: package:
      (
        if package ? testContext then
          package.testContext.mkBatch
        else
          args: tvpLib.tests.compatibility.mkBatch (args // { inherit pkgs; })
      )
        {
          inherit name;
          suite = package.tests;
        }
    ) (pkgs.lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") allVariantPackages);
  };

  testBatches = testBatchEntries // {
    all = tvpLib.tests.compatibility.mkAll {
      inherit pkgs checks;
      batches = testBatchEntries;
    };
  };

  # Separate from testBatches: the full plan enumerates every entry but `all`.
  # Reuse each package's existing testContext batch without reconstructing it.
  latestSelection = tvpLib.tests.selectLatest {
    inherit canonical packages;
    batches = packageTestBatches;
  };
  latestTests = latestSelection // {
    all = tvpLib.tests.mkLatest {
      context = tvpLib.tests.fromPackage {
        builder = tvp.builder;
        package = packages.coreutils;
      };
      selection = latestSelection;
    };
  };
  smokeTests = import ./smoke.nix { inherit pkgs tvp; };
in
{
  # The flattened variants are a private handle shared with the check registry.
  inherit
    testBatches
    latestTests
    smokeTests
    testBatchEntries
    allVariantPackages
    ;
}
