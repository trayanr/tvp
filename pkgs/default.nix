{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  sdks = import ./sdks { inherit pkgs tvp; };
  data = import ./data { inherit pkgs tvp; };
  compilers = import ./compilers { inherit pkgs tvp; };
  libraries = import ./libraries { inherit pkgs tvp; };
  runtimes = import ./runtimes { inherit pkgs tvp; };
  build-tools = import ./build-tools { inherit pkgs tvp; };
}
