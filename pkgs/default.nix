{ pkgs, tvp }:
tvp.lib.packages.merge {
  compilers = import ./compilers { inherit pkgs tvp; };
  libraries = import ./libraries { inherit pkgs tvp; };
  runtimes = import ./runtimes { inherit pkgs tvp; };
  build-tools = import ./build-tools { inherit pkgs tvp; };
}
