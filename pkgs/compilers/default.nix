{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  llvm = import ./llvm { inherit pkgs tvp; };
  go = import ./go { inherit pkgs tvp; };
  go-bootstrap = import ./go-bootstrap { inherit pkgs tvp; };
  rust = import ./rust { inherit pkgs tvp; };
  gcc = import ./gcc { inherit pkgs tvp; };
}
