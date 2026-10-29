{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  ca-certificates = import ./ca-certificates { inherit pkgs tvp; };
}
