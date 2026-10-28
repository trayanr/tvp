# Serves 6.3.0 onwards.
{
  lib,
  stdenv,
  fetchurl,
  m4,
  version,
  sha256,
  cxx ? true,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gmp";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/gmp/gmp-${version}.tar.xz";
    inherit sha256;
  };
  buildInputs = [ ];
  nativeBuildInputs = [ m4 ];
  configureFlags = [
    (lib.enableFeature cxx "cxx")
    "--with-pic"
  ];
  enableParallelBuilding = true;
  doCheck = true;
  meta = {
    description = "GNU multiple-precision arithmetic library";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = {
      inherit m4;
    };
    tvp.cc = stdenv.cc;
    tvp.features.cxx = cxx;
    tests = mkTests finalAttrs.finalPackage;
  };
})
