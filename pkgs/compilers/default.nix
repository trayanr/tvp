{ pkgs, tvp }:
tvp.lib.packages.merge {
  rust = import ./rust { inherit pkgs tvp; };
}
