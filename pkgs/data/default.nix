{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  ca-certificates = import ./ca-certificates { inherit pkgs tvp; };
  tzdata = import ./tzdata { inherit pkgs tvp; };
}
