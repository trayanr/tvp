{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  go = import ./go { inherit pkgs tvp; };
  go-bootstrap = import ./go-bootstrap { inherit pkgs tvp; };
  rust = import ./rust { inherit pkgs tvp; };
  gcc = import ./gcc { inherit pkgs tvp; };
}
