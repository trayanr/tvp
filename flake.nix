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
        };
        tvp = import ./. { inherit pkgs system; };
      in
      {
        inherit (tvp) packages checks;

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

        # Not a standard flake output; `nix flake check` notes it as unknown.
        # One buildable attribute per CI matrix job.
        testBatches = tvp.testBatches;
      }
    );
}
