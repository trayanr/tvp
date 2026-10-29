{ pkgs, tvp }:
tvp.lib.packages.mergeNamespaces {
  libxcrypt = import ./libxcrypt { inherit pkgs tvp; };
  attr = import ./attr { inherit pkgs tvp; };
  acl = import ./acl { inherit pkgs tvp; };
  pcre2 = import ./pcre2 { inherit pkgs tvp; };
  glibc = import ./glibc { inherit pkgs tvp; };
  linux-headers = import ./linux-headers { inherit pkgs tvp; };
  gmp = import ./gmp { inherit pkgs tvp; };
  mpfr = import ./mpfr { inherit pkgs tvp; };
  mpdecimal = import ./mpdecimal { inherit pkgs tvp; };
  mpc = import ./mpc { inherit pkgs tvp; };
  isl = import ./isl { inherit pkgs tvp; };
  openssl = import ./openssl { inherit pkgs tvp; };
  libxml2 = import ./libxml2 { inherit pkgs tvp; };
  ncurses = import ./ncurses { inherit pkgs tvp; };
  readline = import ./readline { inherit pkgs tvp; };
  zlib = import ./zlib { inherit pkgs tvp; };
  zstd = import ./zstd { inherit pkgs tvp; };
  gdbm = import ./gdbm { inherit pkgs tvp; };
  libyaml = import ./libyaml { inherit pkgs tvp; };
  libffi = import ./libffi { inherit pkgs tvp; };
  xz = import ./xz { inherit pkgs tvp; };
  sqlite = import ./sqlite { inherit pkgs tvp; };
}
