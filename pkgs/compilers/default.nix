{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  rust = import ./rust { inherit pkgs tvp; };
  gcc = import ./gcc { inherit pkgs tvp; };
}
