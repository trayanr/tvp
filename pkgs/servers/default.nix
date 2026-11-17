{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  redis = import ./redis { inherit pkgs tvp; };
}
