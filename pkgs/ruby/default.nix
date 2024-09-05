{pkgs, tvp} : rec {
  ruby_2_7_0 = import ./ruby-2.7.0.nix {
	inherit (pkgs) lib stdenv fetchurl;
	openssl = pkgs.openssl_1_1;
	inherit (pkgs) readline zlib gdbm;
  };
  ruby = ruby_2_7_0;
} 
