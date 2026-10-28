# Serves 2.4.2 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  version,
  sha256,
  float128 ? true,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
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
    tests = mkTests finalAttrs.finalPackage;
  };
})
