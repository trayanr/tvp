# Gawk 4.0 has Readline but predates the GMP/MPFR arithmetic interface.
{
  lib,
  stdenv,
  fetchurl,
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
    readline
    ncurses
  ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU AWK";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit
        readline
        ncurses
        ;
    };
    tvp.features.bignum = false;
    tvp.readlineProgram = "dgawk";
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
