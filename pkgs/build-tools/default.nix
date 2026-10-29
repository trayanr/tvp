{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  gradle = import ./gradle { inherit pkgs tvp; };
  git = import ./git { inherit pkgs tvp; };
  curl = import ./curl { inherit pkgs tvp; };
  gn = import ./gn { inherit pkgs tvp; };
  unzip = import ./unzip { inherit pkgs tvp; };
  zip = import ./zip { inherit pkgs tvp; };
  gperf = import ./gperf { inherit pkgs tvp; };
  cargo-bootstrap = import ./cargo-bootstrap { inherit pkgs tvp; };
  coreutils = import ./coreutils { inherit pkgs tvp; };
  findutils = import ./findutils { inherit pkgs tvp; };
  diffutils = import ./diffutils { inherit pkgs tvp; };
  gnused = import ./gnused { inherit pkgs tvp; };
  gnugrep = import ./gnugrep { inherit pkgs tvp; };
  gawk = import ./gawk { inherit pkgs tvp; };
  gnutar = import ./gnutar { inherit pkgs tvp; };
  gzip = import ./gzip { inherit pkgs tvp; };
  bzip2 = import ./bzip2 { inherit pkgs tvp; };
  gnumake = import ./gnumake { inherit pkgs tvp; };
  patch = import ./patch { inherit pkgs tvp; };
  file = import ./file { inherit pkgs tvp; };
  autoconf = import ./autoconf { inherit pkgs tvp; };
  automake = import ./automake { inherit pkgs tvp; };
  libtool = import ./libtool { inherit pkgs tvp; };
  flex = import ./flex { inherit pkgs tvp; };
  bundler = import ./bundler { inherit pkgs tvp; };
  binutils = import ./binutils { inherit pkgs tvp; };
  bison = import ./bison { inherit pkgs tvp; };
  texinfo = import ./texinfo { inherit pkgs tvp; };
  which = import ./which { inherit pkgs tvp; };
  m4 = import ./m4 { inherit pkgs tvp; };
  pkg-config = import ./pkg-config { inherit pkgs tvp; };
  patchelf = import ./patchelf { inherit pkgs tvp; };
  ninja = import ./ninja { inherit pkgs tvp; };
  cmake = import ./cmake { inherit pkgs tvp; };
  meson = import ./meson { inherit pkgs tvp; };
}
