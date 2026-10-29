# Serves 4.3 onwards. Earlier releases need a period glibc.
{
  lib,
  stdenv,
  fetchurl,
  version,
  sha256,
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gnumake";
  inherit version;
  src = fetchurl {
    url = "https://mirrors.kernel.org/gnu/make/make-${version}.tar.gz";
    inherit sha256;
  };
  buildInputs = [ ];
  enableParallelBuilding = true;
  configureFlags = [ ];

  meta = {
    description = "GNU Make build tool";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
  passthru = {
    tvp.deps = { };
    tvp.cc = stdenv.cc;
    tests = mkTests finalAttrs.finalPackage;
  };
})
