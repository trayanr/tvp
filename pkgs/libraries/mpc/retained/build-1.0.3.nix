# Serves 1.0.3 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  mpfr,
  version,
  sha256,
  archiveExt ? "tar.gz",
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mpc";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.${archiveExt}";
    inherit sha256;
  };
  propagatedBuildInputs = [
    gmp
    mpfr
  ];
  configureFlags = [
    "--with-gmp=${lib.getDev gmp}"
    "--with-mpfr=${lib.getDev mpfr}"
  ];
  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "Multiple-precision complex arithmetic library";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit gmp mpfr;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
