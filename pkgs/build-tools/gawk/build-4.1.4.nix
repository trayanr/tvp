# Gawk 4.1 onward adds the GMP/MPFR arbitrary-precision interface.
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
  cStandard ? null,
  configureCFlags ? [ ],
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
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
      tvp.features.bignum = true;
      tvp.readlineProgram = "gawk";
      tvp.cc = stdenv.cc;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (cStandard != null && lib.versionAtLeast stdenv.cc.version "15") {
    env.NIX_CFLAGS_COMPILE = "-std=${cStandard}";
  }
  // lib.optionalAttrs (configureCFlags != [ ] && lib.versionAtLeast stdenv.cc.version "14") {
    preConfigure = ''
      tvpGawkBuildCflags="$NIX_CFLAGS_COMPILE"
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " configureCFlags}"
    '';
    postConfigure = ''
      export NIX_CFLAGS_COMPILE="$tvpGawkBuildCflags"
    '';
  }

)
