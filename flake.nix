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
        tvp = import ./. { inherit pkgs system; };
      in
      {
        inherit (tvp) packages checks;

        # legacyPackages, not a bare output: `packages.<system>.<name>` must be
        # derivations and these are nested. Resolves as `.#canonical.<attr>` or
        # `.#variants.<profile>.<attr>`.
        legacyPackages = {
          inherit (tvp) canonical variants android;
        };

        formatter = pkgs.nixfmt-rfc-style;

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

        testPlans = tvp.lib.tests.mkPlan {
          inherit pkgs;
          batches = removeAttrs tvp.testBatches [ "all" ];
          inherit (tvp) checks canonical;
          source = self.outPath;
          revision = self.rev or self.dirtyRev or null;
        };

        # Not a standard flake output; `nix flake check` notes it as unknown.
        # One buildable attribute per CI matrix job.
        testBatches = tvp.testBatches;
      }
    );
}
