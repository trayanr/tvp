# Serves 0.20 onwards.
{
  lib,
  stdenv,
  fetchurl,
  gmp,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "isl";
  inherit version;
  src = fetchurl {
    url = "https://libisl.sourceforge.io/isl-${version}.tar.xz";
    inherit sha256;
  };
  propagatedBuildInputs = [ gmp ];
  configureFlags = [
    "--with-gmp=system"
    "--with-gmp-prefix=${lib.getDev gmp}"
  ];
  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "Integer sets and relations library for polyhedral compilation";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit gmp;
    };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
