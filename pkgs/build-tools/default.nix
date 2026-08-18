{ pkgs, tvp }:
tvp.lib.packages.merge {
  autoconf = import ./autoconf { inherit pkgs tvp; };
  bundler = import ./bundler { inherit pkgs tvp; };
  m4 = import ./m4 { inherit pkgs tvp; };
  pkg-config = import ./pkg-config { inherit pkgs tvp; };
}
