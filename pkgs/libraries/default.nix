{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  openssl = import ./openssl { inherit pkgs tvp; };
  libxml2 = import ./libxml2 { inherit pkgs tvp; };
  ncurses = import ./ncurses { inherit pkgs tvp; };
  readline = import ./readline { inherit pkgs tvp; };
  zlib = import ./zlib { inherit pkgs tvp; };
  gdbm = import ./gdbm { inherit pkgs tvp; };
}
