{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  redis = import ./redis { inherit pkgs tvp; };
  postgresql = import ./postgresql { inherit pkgs tvp; };
  mariadb = import ./mariadb { inherit pkgs tvp; };
}
