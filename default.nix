{
  system ? "x86_64-linux", # currently unused?
  config ? {},
  pkgs, # TODO: nixpkgs check and abort if not or auto import channel
}: let 

  packages = {
	openssl_1_1_1 = pkgs.callPackage ./pkgs/openssl-1.1.1.nix { };
  } 
  // (import ./pkgs/ruby {inherit pkgs tvp; })
  // (import ./pkgs/bundler {inherit pkgs tvp; }); 
  tvp = { inherit packages; };

in tvp
