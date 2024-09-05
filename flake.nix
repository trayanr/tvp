{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
	flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
		  inherit system;
		  config.permittedInsecurePackages = [
			"openssl-1.1.1w"
          ];
		};
      in
      {
		# at some point will split the lib and pkgs and create a separate lib
        packages = {
		  openssl_1_1_1 = pkgs.callPackage ./pkgs/openssl-1.1.1.nix { };
        } // (import ./pkgs/ruby {inherit pkgs; tvp = self;});
      }
    ); 
}
