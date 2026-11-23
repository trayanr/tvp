{
  description = "TVP — versioned packages that stay buildable";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    {
      lib = import ./lib { inherit (nixpkgs) lib; };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.permittedInsecurePackages = [
            "openssl-1.1.1w"
          ];
          # The SDK components are explicitly requested binary distributions.
          # Keep their upstream licence metadata and scope the allowance to them.
          config.allowUnfreePredicate =
            p:
            builtins.elem (nixpkgs.lib.getName p) [
              "android-cli"
              "android-commandline-tools"
              "android-platform-tools"
              "android-build-tools"
              "android-platform"
              "android-ndk"
            ];
        };
        tvp = import ./. {
          inherit pkgs system;
        };
        testPkgs = pkgs // tvp.__testBuilders;
      in
      {
        inherit (tvp) packages checks;

        # legacyPackages, not a bare output: `packages.<system>.<name>` must be
        # derivations and these are nested. Resolves as `.#canonical.<attr>` or
        # `.#variants.<profile>.<attr>`.
        legacyPackages = {
          inherit (tvp)
            canonical
            variants
            android
            php
            graph
            dependencyRoots
            dependencyInventory
            provenanceDeclarations
            upstreamIsolationInventory
            upstreamIsolationReport
            upstreamIsolationStrict
            recipeSplitInventory
            recipeSplitReport
            recipeSplitStrict
            ;
          upstreamManifest = tvp.tools.upstream.manifest;
        };

        formatter = tvp.packages.nixfmt_1_5_0;

        apps.tvp = {
          type = "app";
          program = "${tvp.tools.consumer}/bin/tvp";
        };

        apps.dependencies = {
          type = "app";
          program = "${tvp.tools.dependencies}/bin/tvp-dependencies";
        };

        apps.provenance = {
          type = "app";
          program = "${tvp.tools.provenance}/bin/tvp-provenance";
        };

        apps.upstream = {
          type = "app";
          program = "${tvp.tools.upstream}/bin/tvp-upstream";
        };

        apps.neutral = {
          type = "app";
          program = "${tvp.tools.neutral}/bin/tvp-neutral";
        };

        apps.status = {
          type = "app";
          program = "${tvp.tools.status}/bin/tvp-status";
        };

        apps.test = {
          type = "app";
          program = "${tvp.tools.testRunner}/bin/tvp-test";
        };

        testPlans = tvp.lib.tests.compatibility.mkPlan {
          pkgs = testPkgs;
          batches = removeAttrs tvp.testBatches [ "all" ];
          inherit (tvp) checks canonical;
          source = self.outPath;
          revision = self.rev or self.dirtyRev or null;
        };

        catalogueTestPlans = tvp.cataloguePlan {
          source = self.outPath;
          revision = self.rev or self.dirtyRev or null;
        };

        smokeTestPlans = tvp.lib.tests.compatibility.mkPlan {
          pkgs = testPkgs;
          batches = tvp.smokeTests.batches;
          checks = { };
          canonical = { };
          smoke = true;
          source = self.outPath;
          revision = self.rev or self.dirtyRev or null;
        };

        testCatalogues = import ./lib/test-catalogue.nix {
          pkgs = testPkgs;
          inherit (tvp) canonical packages variants;
          batches = tvp.testBatches;
          source = self.outPath;
          revision = self.rev or self.dirtyRev or null;
        };

        # Not a standard flake output; `nix flake check` notes it as unknown.
        # One buildable attribute per CI matrix job.
        testBatches = tvp.testBatches;
        latestTests = tvp.latestTests;
        smokeTests = tvp.smokeTests;

        smokeTestPlanParts = {
          planPart =
            { index, count }:
            tvp.lib.tests.compatibility.smokePlanPart {
              inherit (tvp.smokeTests) batches;
              inherit index count;
            };
          joinPlan =
            { parts, references }:
            tvp.lib.tests.compatibility.joinSmokePlan {
              pkgs = testPkgs;
              inherit parts references;
              inherit (tvp.smokeTests) batches;
              source = self.outPath;
              revision = self.rev or self.dirtyRev or null;
            };
        };
      }
    );
}
