{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  dart-bootstrap = import ./dart-bootstrap { inherit pkgs tvp; };
  jdk-bootstrap = import ./jdk-bootstrap { inherit pkgs tvp; };
  jdk = import ./jdk { inherit pkgs tvp; };
  nodejs = import ./nodejs { inherit pkgs tvp; };
  bash = import ./bash { inherit pkgs tvp; };
  perl = import ./perl { inherit pkgs tvp; };
  python-minimal = import ./python-minimal { inherit pkgs tvp; };
  php = import ./php { inherit pkgs tvp; };
  ruby = import ./ruby { inherit pkgs tvp; };
  tcl = import ./tcl { inherit pkgs tvp; };
  python = import ./python { inherit pkgs tvp; };
  python-build = import ./python-build { inherit pkgs tvp; };
}
