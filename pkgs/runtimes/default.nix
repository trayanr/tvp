{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  perl = import ./perl { inherit pkgs tvp; };
  php = import ./php { inherit pkgs tvp; };
  ruby = import ./ruby { inherit pkgs tvp; };
}
