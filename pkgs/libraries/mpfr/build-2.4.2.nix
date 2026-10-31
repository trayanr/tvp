# Serves 2.4.2 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  version,
  sha256,
  checkCFlags ? [ ],
  float128 ? true,
  mpfrRoundingNames ? true,
  mkTests,
}:
stdenv.mkDerivation (
  finalAttrs:
  {
    pname = "mpfr";
    inherit version;
    src = fetchurl {
      url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
      inherit sha256;
    };
    propagatedBuildInputs = [ gmp ];
    configureFlags = [
      "--with-gmp=${lib.getDev gmp}"
    ] ++ lib.optional (!float128) "--disable-float128";
    enableParallelBuilding = true;
    doCheck = true;
    meta = {
      description = "Correctly rounded multiple-precision floating-point arithmetic";
      license = lib.licenses.lgpl3Plus;
      platforms = lib.platforms.unix;
    };
    passthru = {
      tvp.deps = {
        inherit gmp;
      };
      tvp.cc = stdenv.cc;
      tvp.features.float128 = float128;
      tvp.features.mpfrRoundingNames = mpfrRoundingNames;
      tests = mkTests finalAttrs.finalPackage;
    };
  }
  // lib.optionalAttrs (checkCFlags != [ ] && lib.versionAtLeast stdenv.cc.version "15") {
    preCheck = ''
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " checkCFlags}"
    '';
  }
)
