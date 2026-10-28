# Serves 5.2.2 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  mpfr,
  readline,
  ncurses,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gawk";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/gawk/gawk-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [
    gmp
    mpfr
    readline
    ncurses
  ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU AWK with arbitrary precision arithmetic";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit
        gmp
        mpfr
        readline
        ncurses
        ;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
