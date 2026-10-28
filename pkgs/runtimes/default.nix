{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  bash = import ./bash { inherit pkgs tvp; };
  perl = import ./perl { inherit pkgs tvp; };
  php = import ./php { inherit pkgs tvp; };
  ruby = import ./ruby { inherit pkgs tvp; };
  tcl = import ./tcl { inherit pkgs tvp; };
}
