{
  system ? "x86_64-linux",
  config ? { },
  source ? {
    path = toString ./.;
    revision = null;
  },
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
      variantPackages
      ;
    runtimeRegistry = reports.runtimeRegistry;
  };
  inherit (toolSet) ownedCLI tools;

  checks = import ./checks {
    inherit
      pkgs
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
    inherit
      pkgs
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
      packages
      variants
      construction
      legacyBases
      tools
      checks
      source
      system
      ;
    inherit (testSet) testBatchEntries;
    inherit (packageSet) familyEntrypoints;
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
      migrationStatusManifest
      upstreamIsolationInventory
      upstreamIsolationReport
      upstreamIsolationStrict
      recipeSplitInventory
      recipeSplitReport
      recipeSplitStrict
      dependencyRoots
      dependencyInventory
      graph
      ;
    android = import ./sdks/android.nix { inherit tvp pkgs; };
    # Internal compatibility only; ordinary packages use the public bases above.
    __legacyBases = legacyBases;
    builder = import ./lib/builder.nix { inherit (pkgs) lib; };
    lib = tvpLib;
  };
in
tvp
