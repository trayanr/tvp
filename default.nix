{
  system ? "x86_64-linux",
  config ? { },
  pkgs, # TODO: nixpkgs check and abort if not or auto import channel
}:
assert
  pkgs.stdenv.hostPlatform.system == system
  || throw "TVP: requested system ${system} differs from the supplied package context ${pkgs.stdenv.hostPlatform.system}";
let
  tvpLib = import ./lib {
    inherit (pkgs) lib;
    familyContext = {
      base = bases.default;
      builder = tvp.builder;
      helpers = {
        inherit tvp;
        inherit (pkgs) lib;
      };
    };
  };

  # Legacy recipe syntax uses checked views of the source-owned bases.
  retained = import ./bases/retained.nix {
    inherit bases tvpLib;
    inherit (pkgs) lib config;
    builder = tvp.builder;
  };
  inherit (retained) legacyBases construction;
  bases = import ./bases {
    inherit system;
    inherit (pkgs) lib;
    builder = tvp.builder;
  };

  packageSet = import ./pkgs { inherit pkgs tvp; };
  inherit (packageSet)
    canonical
    packages
    variants
    variantPackages
    ;

  toolSet = import ./tools {
    inherit
      pkgs
      tvp
      tvpLib
      canonical
      bases
      legacyBases
      ;
  };
  inherit (toolSet) ownedCLI tools;

  testBuilders = import ./tests/builders.nix {
    inherit pkgs tvp;
    base = bases.default;
    legacyBase = legacyBases.default;
  };
  testPkgs = pkgs // testBuilders;
  checks = import ./checks {
    pkgs = testPkgs;
    inherit
      tvp
      tvpLib
      canonical
      bases
      legacyBases
      construction
      ownedCLI
      ;
    inherit (packageSet) recipes familyEntrypoints;
    inherit (testSet) allVariantPackages;
    runtimeRegistry = reports.runtimeRegistry;
  };
  testSet = import ./tests {
    pkgs = testPkgs;
    inherit
      tvp
      tvpLib
      canonical
      packages
      legacyBases
      construction
      variantPackages
      checks
      ;
  };
  inherit (testSet) testBatches latestTests smokeTests;

  reports = import ./reports {
    inherit
      pkgs
      tvp
      tvpLib
      canonical
      variants
      variantPackages
      construction
      legacyBases
      tools
      checks
      ;
    inherit (testSet) testBatchEntries;
  };

  tvp = {
    inherit
      bases
      canonical
      packages
      variants
      checks
      testBatches
      latestTests
      smokeTests
      tools
      ;
    inherit (reports)
      upstreamIsolationInventory
      upstreamIsolationReport
      upstreamIsolationStrict
      recipeSplitInventory
      recipeSplitReport
      recipeSplitStrict
      dependencyRoots
      dependencyInventory
      provenanceDeclarations
      graph
      ;
    android = import ./sdks/android.nix { inherit tvp pkgs; };
    php = import ./pkgs/runtimes/php/catalogue.nix { inherit tvp pkgs; };
    # Internal compatibility only; ordinary packages use the public bases above.
    __legacyBases = legacyBases;
    __testBuilders = testBuilders;
    inherit (testSet) cataloguePlan;
    builder = import ./lib/builder.nix { inherit (pkgs) lib; };
    lib = tvpLib;
  };
in
tvp
